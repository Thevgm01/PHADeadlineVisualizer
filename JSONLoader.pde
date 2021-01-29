class JSONLoader {
  
  private JSONObject projectManagerMilestones;
  public JSONArray getPMs() { return projectManagerMilestones.getJSONArray("project-managers"); }
  public JSONArray getProjects(String pm) { return projectManagerMilestones.getJSONObject(pm).getJSONArray("project-ids"); }
  public JSONArray getMilestones(String pm, String projectID) { return projectManagerMilestones.getJSONObject(pm).getJSONArray(projectID); }
  public String getProjectName(String projectID) { return projects.getJSONObject(projectID).getString("name"); }

  private JSONObject config;
  private JSONObject milestones;
  private JSONObject projects;
  
  private String configJSONFile = "config.json";
  private String sortedMilestonesJSONFile = "data/sorted_milestones.json";
  private String milestonesJSONFile = "data/milestones.json";
  private String projectsJSONFile = "data/projects.json";
  
  private String password = "password";
  private String api = "/projects/api/v3/";

  private String[] pmWords = {"pm", "project manager"};

  public JSONLoader() {
    config = loadJSONObject(configJSONFile);
    milestones = loadJSONObject(milestonesJSONFile);
    projects = loadJSONObject(projectsJSONFile);
    //projectManagerMilestones = loadJSONObject(sortedMilestonesJSONFile);
    createSortedJSON();
  }
  
  public JSONLoader(String username) {
    config = loadJSONObject(configJSONFile);
    downloadMilestonesJSON();
    downloadProjectsJSON();
    setProjectManagers();
    createSortedJSON();
  }

  // Get all upcoming milestones
  private void downloadMilestonesJSON() {
    String username = config.getString("user-api-token");
    String url = config.getString("company-teamwork-url");
    JSONArray milestoneWhitelist = config.getJSONArray("milestone-whitelist");
    JSONArray milestoneBlacklist = config.getJSONArray("milestone-blacklist");
    
    milestones = new JSONObject();
    JSONArray milestoneIDs = new JSONArray();
    milestones.setJSONArray("ids", milestoneIDs);
    
    Calendar beginningOfMonth = Calendar.getInstance();
    beginningOfMonth.set(Calendar.DAY_OF_MONTH, 0);
    String curDate = dateParser.format(beginningOfMonth.getTime());
    
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
        if(stringContainsIgnoreCase(milestone.getString("name"), milestoneWhitelist) &&
          !stringContainsIgnoreCase(milestone.getString("name"), milestoneBlacklist)) {
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
    String username = config.getString("user-api-token");
    String url = config.getString("company-teamwork-url");
    
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
    JSONObject pms = config.getJSONObject("project-managers");
    JSONArray pmNames = pms.getJSONArray("names");
    for(int i = 0; i < pmNames.size(); ++i) {
      String name = pmNames.getString(i);
      pms.getJSONObject(name).setJSONArray("permutations", getNamePermutations(name));
    }
    
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
    JSONObject pms = config.getJSONObject("project-managers");
    JSONArray pmNames = pms.getJSONArray("names");
    
    String[] lines = desc.toLowerCase().split("\n");
    for(int i = 0; i < lines.length; ++i) {
      if(lines[i].length() < 30 && (lines[i].contains(pmWords[0]) || lines[i].contains(pmWords[1]))) {
        String pm = lines[i];
        for(int k = 0; k < pmWords.length; ++k)
          pm = pm.replace(pmWords[k], "");
        pm = pm.replaceAll("[^\\w\\s]", "");
        pm = pm.trim();
        
        for(int j = 0; j < pmNames.size(); ++j) {
          String name = pmNames.getString(i);
          if(stringContainsIgnoreCase(pm, pms.getJSONObject(name).getJSONArray("permutations"))) {
            return name;
          }
        }
      }
    }
    return "Unknown";
  }
  
  private JSONArray getNamePermutations(String name) {
    String[] words = name.toLowerCase().split(" "); 
    JSONArray result = new JSONArray();
    
    result.append(words[0]); // Steven
    if(words.length == 1) {
      result.append(words[1]); // Dunn
      result.append(words[0] + " " + words[1]); // Steven Dunn
      result.append(words[0] + " " + words[1].substring(0)); // Steven D
      result.append(words[0].substring(0) + " " + words[1]); // S Dunn
      result.append(words[0].substring(0) + words[1].substring(0)); // SD
    }
    return result;
  }
  
  private void createSortedJSON() {
    
    projectManagerMilestones = new JSONObject();
    JSONArray projectManagerNames = new JSONArray();
    projectManagerMilestones.setJSONArray("project-managers", projectManagerNames);

    JSONArray milestoneIDs = milestones.getJSONArray("ids");
    for(int i = 0; i < milestoneIDs.size(); ++i) { // For each milestone
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      
      String pmName = milestone.getString("project-manager"); // Get the project manager
      String projectID = milestone.getJSONObject("project").getInt("id") + "";
            
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
  
  boolean stringContainsIgnoreCase(String target, JSONArray tests) {
    target = target.toLowerCase();
    for(int i = 0; i < tests.size(); ++i) {
      if(target.contains(tests.getString(i).toLowerCase())) {
        return true;
      }
    }
    return false;
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
