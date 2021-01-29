class JSONLoader {
  
  private JSONObject projectManagerMilestones;
  public JSONArray getPMs() { return projectManagerMilestones.getJSONArray("project-managers"); }
  public JSONArray getProjects(String pm) { return projectManagerMilestones.getJSONObject(pm).getJSONArray("project-ids"); }
  public JSONArray getMilestones(String pm, String projectID) { return projectManagerMilestones.getJSONObject(pm).getJSONArray(projectID); }

  private JSONObject milestones;
  private JSONObject projects;
  
  private String sortedMilestonesJSONFile = "data/sorted_milestones.json";
  private String milestonesJSONFile = "data/milestones.json";
  private String projectsJSONFile = "data/projects.json";
  private String milestoneWhitelistFile = "MilestoneWhitelist.txt";
  
  private String url = "https://phaconsulting.teamwork.com";
  private String api = "/projects/api/v3/";
  private String username = "";
  private String password = "password";
    
  private String[] pmWords = {"PM", "PROJECT MANAGER"};
  //private String[] randy = {"Randy", "Visser"};
  //private String[] tim = {"Tim", "Russel"};
  
  public JSONLoader() {
    milestones = loadJSONObject(milestonesJSONFile);
    projects = loadJSONObject(projectsJSONFile);
    //projectManagerMilestones = loadJSONObject(sortedMilestonesJSONFile);
    createSortedJSON();
  }
  
  public JSONLoader(String username) {
    this.username = username;
    downloadMilestonesJSON();
    downloadProjectsJSON();
    setProjectManagers();
    createSortedJSON();
  }

  // Get all upcoming milestones
  private void downloadMilestonesJSON() {    
    milestones = new JSONObject();
    JSONArray milestoneIDs = new JSONArray();
    milestones.setJSONArray("ids", milestoneIDs);
    
    String curDate = creationParser.format(new Date());
    String[] milestoneWhitelist = loadStrings(milestoneWhitelistFile);
    for(int i = 0; i < milestoneWhitelist.length; ++i) {
      
      String term = milestoneWhitelist[i];
      
      GetRequest get = new GetRequest(
        url + api + "milestones.json" + 
        "?dueAfter=" + curDate +
        "&searchTerm=" + term);
      get.addUser(username, password);
      get.send();
      
      JSONObject foundMilestones = parseJSONObject(get.getContent());
      JSONArray milestonesArray = foundMilestones.getJSONArray("milestones");
      for(int j = 0; j < milestonesArray.size(); ++j) {
        JSONObject milestone = milestonesArray.getJSONObject(j);
        println("\n\n\n\n" + milestone);
        String id = milestone.getInt("id") + "";
        milestones.setJSONObject(id, milestone);
        milestoneIDs.append(id);
      }
    }
    
    //GetRequest get = new GetRequest(url + "milestones.json?find=upcoming");
    //GetRequest get = new GetRequest(url + "milestones.json");
    
    saveJSONObject(milestones, milestonesJSONFile);
    exit();
  }
  
  // Get the project associated with each milestone
  private void downloadProjectsJSON() {
    projects = new JSONObject();
    JSONArray projectIDs = new JSONArray();
    projects.setJSONArray("ids", projectIDs);
    
    JSONArray milestoneIDs = milestones.getJSONArray("ids");
    for(int i = 0; i < milestoneIDs.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      String projectID = milestone.getString("project-id");
      
      if(!projects.isNull(projectID)) // Skip if we've downloaded this project ID before
        continue;
      
      GetRequest projectGet = new GetRequest(url + api + "projects/api/v3/projects/" + projectID + ".json");
      projectGet.addUser(username, password);
      //println(url + "projects/" + id + ".json");
      projectGet.send();
      
      JSONObject project = parseJSONObject(projectGet.getContent());
      projects.setJSONObject(projectID, project);
      projectIDs.append(projectID);
      
    }
    
    saveJSONObject(projects, projectsJSONFile); 
  }
  
  private void setProjectManagers() {
    JSONArray milestoneIDs = milestones.getJSONArray("ids");
    for(int i = 0; i < milestoneIDs.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      String projectID = milestone.getString("project-id");
      JSONObject project = projects.getJSONObject(projectID);

      if(project.isNull("project-manager"))
        project.setString("project-manager", getProjectManager(project));
        
      milestone.setString("project-manager", project.getString("project-manager"));
    }
    
    saveJSONObject(milestones, milestonesJSONFile);
    saveJSONObject(projects, projectsJSONFile);
  }
  
  private String getProjectManager(JSONObject project) {
    JSONObject projectInfo = project.getJSONObject("project");
    String desc = projectInfo.getString("description");
    
    String[] lines = desc.toUpperCase().split("\n");
    for(int j = 0; j < lines.length; ++j) {
      if(lines[j].length() < 30 && (lines[j].contains(pmWords[0]) || lines[j].contains(pmWords[1]))) {
        String pm = lines[j];
        for(int k = 0; k < pmWords.length; ++k)
          pm = pm.replace(pmWords[k], "");
        pm = pm.replaceAll("[^\\w\\s]", "");
        pm = pm.trim();
        return pm;
      }
    }
    return "UNKNOWN";
  }
  
  private void createSortedJSON() {
    String[] milestoneWhitelist = loadStrings(milestoneWhitelistFile);
    //String[] milestoneBlacklist;
    
    projectManagerMilestones = new JSONObject();
    JSONArray projectManagerNames = new JSONArray();
    projectManagerMilestones.setJSONArray("project-managers", projectManagerNames);

    JSONArray milestoneIDs = milestones.getJSONArray("ids");
    for(int i = 0; i < milestoneIDs.size(); ++i) { // For each milestone
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      
      if(!stringContains(milestone.getString("title"), milestoneWhitelist)) {
        continue; 
      }
      
      String pmName = milestone.getString("project-manager"); // Get the project manager
      String projectID = milestone.getString("project-id");
      
      JSONObject project = projects.getJSONObject(projectID);
      
      JSONObject pm = projectManagerMilestones.getJSONObject(pmName);
      if(pm == null) {
        pm = new JSONObject();
        projectManagerMilestones.setJSONObject(pmName, pm); 
        projectManagerNames.append(pmName);
      }
      
      JSONArray pmProjectMilestones = pm.getJSONArray(projectID);
      if(pmProjectMilestones == null) {
        pmProjectMilestones = new JSONArray();
        pm.setJSONArray(projectID, pmProjectMilestones);
        
        JSONArray pmProjectIDs = pm.getJSONArray("project-ids");
        if(pmProjectIDs == null) {
          pmProjectIDs = new JSONArray();
          pm.setJSONArray("project-ids", pmProjectIDs);
        }
     
        pmProjectIDs.append(projectID);
      }
            
      pmProjectMilestones.append(milestone);
    }
    
    sortPMs();
    
    saveJSONObject(projectManagerMilestones, sortedMilestonesJSONFile);
  }
  
  boolean stringContains(String target, String[] tests) {
    target = target.toLowerCase();
    boolean whitelisted = false;
    for(int j = 0; j < tests.length; ++j) {
      if(target.contains(tests[j].toLowerCase())) {
        whitelisted = true;
        break;
      }
    }
    return whitelisted;
  }
  
  void sortPMs() {
    JSONArray pms = projectManagerMilestones.getJSONArray("project-managers");
    for(int i = 0; i < pms.size(); ++i) {
      JSONArray projectIDsA = projectManagerMilestones.getJSONObject(pms.getString(i)).getJSONArray("project-ids");
      for(int j = i + 1; j < pms.size(); ++j) {
        JSONArray projectIDsB = projectManagerMilestones.getJSONObject(pms.getString(j)).getJSONArray("project-ids");
        if(projectIDsA.size() < projectIDsB.size()) {
          String temp = pms.getString(i);
          pms.setString(i, pms.getString(j));
          pms.setString(j, temp);
        }
      }
    }
  }
}
