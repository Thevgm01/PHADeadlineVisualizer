class JSONLoader {
  
  private JSONObject projectManagerMilestones;
  public JSONArray getPMs() { return projectManagerMilestones.getJSONArray("project-managers"); }
  public JSONArray getProjects(String pm) { return projectManagerMilestones.getJSONObject(pm).getJSONArray("project-ids"); }
  public JSONArray getMilestones(String pm, String projectID) { return projectManagerMilestones.getJSONObject(pm).getJSONArray(projectID); }
  public String getProjectName(String projectID) { return projects.getJSONObject(projectID).getString("name"); }

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
  private String[] randy = {"Randy", "Visser", "RV", "Randy V", "V Randy", "Randy Visser"};
  private String[] tim = {"Tim", "Russel", "TR", "Tim R", "T Russel", "Tim Russel"};
  private String[] aa = {"Andrew", "Allen", "AA", "A Allen", "Andrew A", "Andrew Allen"};
  private String[] tk = {"TK"};

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
    
    Calendar beginningOfMonth = Calendar.getInstance();
    beginningOfMonth.set(Calendar.DAY_OF_MONTH, 0);
    String curDate = creationParser.format(beginningOfMonth.getTime());
    String[] milestoneWhitelist = loadStrings(milestoneWhitelistFile);
    
    int page = 0;
    boolean hasMore = true;
    while(hasMore) {
      GetRequest get = new GetRequest(url + api + "milestones.json?dueAfter=" + curDate + "&page=" + ++page);
      get.addUser(username, password);
      get.send();
    
      JSONObject foundMilestones = parseJSONObject(get.getContent());
      JSONArray milestonesArray = foundMilestones.getJSONArray("milestones");
      for(int j = 0; j < milestonesArray.size(); ++j) {
        JSONObject milestone = milestonesArray.getJSONObject(j);
        if(stringContainsIgnoreCase(milestone.getString("name"), milestoneWhitelist)) {
          String id = milestone.getInt("id") + "";
          milestones.setJSONObject(id, milestone);
          milestoneIDs.append(id);
        }
      }
      
      hasMore = foundMilestones.getJSONObject("meta").getJSONObject("page").getBoolean("hasMore");
    }
        
    saveJSONObject(milestones, milestonesJSONFile);
  }
  
  // Get the project associated with each milestone
  private void downloadProjectsJSON() {
    projects = new JSONObject();
    JSONArray projectIDs = new JSONArray();
    projects.setJSONArray("ids", projectIDs);
    
    JSONArray milestoneIDs = milestones.getJSONArray("ids");
    String[] projectIDStrings = new String[milestoneIDs.size()];
    for(int i = 0; i < milestoneIDs.size(); ++i)
      projectIDStrings[i] = milestones.getJSONObject(milestoneIDs.getString(i)).getJSONObject("project").getInt("id") + "";
    String projectQuery = String.join(",", projectIDStrings);
    
    GetRequest get = new GetRequest(url + api + "projects.json?projectIds=" + projectQuery);
    get.addUser(username, password);
    get.send();
    
    JSONObject foundProjects = parseJSONObject(get.getContent());
    
    JSONArray projectsArray = foundProjects.getJSONArray("projects");
    for(int i = 0; i < projectsArray.size(); ++i) {
        JSONObject project = projectsArray.getJSONObject(i);
        String id = project.getInt("id") + "";
        projects.setJSONObject(id, project);
        projectIDs.append(id);
    }

    saveJSONObject(projects, projectsJSONFile); 
  }
  
  private void setProjectManagers() {
    JSONArray milestoneIDs = milestones.getJSONArray("ids");
    for(int i = 0; i < milestoneIDs.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      String projectID = milestone.getJSONObject("project").getInt("id") + "";
      JSONObject project = projects.getJSONObject(projectID);

      if(project.isNull("project-manager"))
        project.setString("project-manager", getProjectManager(project));
        
      milestone.setString("project-manager", project.getString("project-manager"));
    }
    
    saveJSONObject(milestones, milestonesJSONFile);
    saveJSONObject(projects, projectsJSONFile);
  }
  
  private String getProjectManager(JSONObject project) {
    String desc = project.getString("description");
    
    String[] lines = desc.toUpperCase().split("\n");
    for(int j = 0; j < lines.length; ++j) {
      if(lines[j].length() < 30 && (lines[j].contains(pmWords[0]) || lines[j].contains(pmWords[1]))) {
        String pm = lines[j];
        for(int k = 0; k < pmWords.length; ++k)
          pm = pm.replace(pmWords[k], "");
        pm = pm.replaceAll("[^\\w\\s]", "");
        pm = pm.trim();
        
        if(stringContainsIgnoreCase(pm, randy)) return "RANDY";
        if(stringContainsIgnoreCase(pm, tim)) return "TIM";
        if(stringContainsIgnoreCase(pm, aa)) return "AA";
        if(stringContainsIgnoreCase(pm, tk)) return "TK";
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
      
      String pmName = milestone.getString("project-manager"); // Get the project manager
      String projectID = milestone.getJSONObject("project").getInt("id") + "";
      
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
  
  boolean stringContainsIgnoreCase(String target, String[] tests) {
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
