class JSONLoader {
  
  private JSONObject projectManagerMilestones;
  public JSONArray getPMs() { return projectManagerMilestones.getJSONArray("projectManagers"); }
  public JSONArray getProjects(String pm) { return projectManagerMilestones.getJSONObject(pm).getJSONArray("projectIds"); }
  public JSONArray getMilestones(String pm, String projectId) { return projectManagerMilestones.getJSONObject(pm).getJSONArray(projectId); }
  public JSONObject getMilestone(String milestoneID) { return milestones.getJSONObject(milestoneID); }
  public String getProjectName(String projectId) { return projects.getJSONObject(projectId).getString("name"); }
  public String getPMHex(String pm) { return "ff" + config.getJSONObject("projectManagers").getJSONObject(pm).getString("color"); }

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

  public JSONLoader(boolean reload) {
    config = loadJSONObject(configJSONFile);
    if(reload) {
      downloadMilestonesJSON();
      downloadProjectsJSON();
      //addPriorMilestones();
    } else {
      milestones = loadJSONObject(milestonesJSONFile);
      projects = loadJSONObject(projectsJSONFile);
    }
    setProjectManagers();
    createSortedJSON();
  }
  
  // Get all upcoming milestones
  private void downloadMilestonesJSON() {
    
    // Config
    String username = config.getString("userToken");
    String url = config.getString("companyTeamworkURL");
    JSONArray milestoneWhitelist = config.getJSONArray("milestoneWhitelist");
    JSONArray milestoneBlacklist = config.getJSONArray("milestoneBlacklist");
    
    // Store milestones
    milestones = new JSONObject();
    JSONArray milestoneIds = new JSONArray();
    milestones.setJSONArray("ids", milestoneIds);
    
    // Download all upcoming milestones (with pagination)
    int page = 0;
    boolean hasMore = true;
    while(hasMore) {
      GetRequest get = new GetRequest(url + api + "milestones.json?status=upcoming&page=" + ++page);
      //GetRequest get = new GetRequest(url + api + "milestones.json?page=" + ++page);
      get.addUser(username, password);
      get.send();
    
      JSONObject foundMilestones = parseJSONObject(get.getContent());
      JSONArray milestonesArray = foundMilestones.getJSONArray("milestones");
      
      // Add found milestones to a JSON object that includes an array with their Ids
      for(int i = 0; i < milestonesArray.size(); ++i) {
        JSONObject milestone = milestonesArray.getJSONObject(i);
        if(checkLists(milestone.getString("name"), milestoneWhitelist, milestoneBlacklist)) {
          String id = milestone.getInt("id") + "";
          milestones.setJSONObject(id, milestone);
          milestoneIds.append(id);
        }
      }
      
      hasMore = foundMilestones.getJSONObject("meta").getJSONObject("page").getBoolean("hasMore");
    }
        
    saveJSONObject(milestones, milestonesJSONFile);
  }
  
  // Get the project associated with each milestone
  private void downloadProjectsJSON() {
    
    // Config
    String username = config.getString("userToken");
    String url = config.getString("companyTeamworkURL");
    
    // Store projects
    projects = new JSONObject();
    JSONArray projectIds = new JSONArray();
    projects.setJSONArray("ids", projectIds);
    
    // Get all project Ids from all milestones and put them inside of a string
    JSONArray milestoneIds = milestones.getJSONArray("ids");
    String[] projectIdStrings = new String[milestoneIds.size()];
    for(int i = 0; i < milestoneIds.size(); ++i)
      projectIdStrings[i] = milestones.getJSONObject(milestoneIds.getString(i)).getInt("projectId") + "";
    String projectQuery = String.join(",", projectIdStrings);
    
    // Request all projects with matching Ids (repeats seem to be okay)
    int page = 0;
    boolean hasMore = true;
    while(hasMore) {
      GetRequest get = new GetRequest(url + api + "projects.json?projectIds=" + projectQuery + "&page=" + ++page);
      get.addUser(username, password);
      get.send();
      
      // Add found projects to a JSON object that includes an array with their Ids
      JSONObject foundProjects = parseJSONObject(get.getContent());
      JSONArray projectsArray = foundProjects.getJSONArray("projects");
      for(int i = 0; i < projectsArray.size(); ++i) {
          JSONObject project = projectsArray.getJSONObject(i);
          String id = project.getInt("id") + "";
          projects.setJSONObject(id, project);
          projectIds.append(id);
      }
      
      hasMore = foundProjects.getJSONObject("meta").getJSONObject("page").getBoolean("hasMore");
    }
    
    saveJSONObject(projects, projectsJSONFile); 
  }
  
  // Set the PM for the milestone and project from the project's description
  private void setProjectManagers() {
    
    // Config
    JSONObject pms = config.getJSONObject("projectManagers");
    
    // Set the name permutations for the config
    JSONArray pmNames = pms.getJSONArray("names");
    for(int i = 0; i < pmNames.size(); ++i) {
      String name = pmNames.getString(i);
      pms.getJSONObject(name).setJSONArray("permutations", getNamePermutations(name));
    }
    //saveJSONObject(config, "temp.json");
    
    // Set the project manager for each project
    JSONArray projectIds = projects.getJSONArray("ids");
    for(int i = 0; i < projectIds.size(); ++i) {
      String projectId = projectIds.getString(i);
      JSONObject project = projects.getJSONObject(projectId);
      project.setString("projectManager", getProjectManager(project));
    }
    
    // Set the project manager for each milestone from its linked project
    JSONArray milestoneIds = milestones.getJSONArray("ids");
    for(int i = 0; i < milestoneIds.size(); ++i) {
      String milestoneId = milestoneIds.getString(i);
      JSONObject milestone = milestones.getJSONObject(milestoneId);
      String projectId = milestone.getInt("projectId") + "";
      JSONObject project = projects.getJSONObject(projectId);
      milestone.setString("projectManager", getProjectManager(project));
    }
    
    saveJSONObject(milestones, milestonesJSONFile);
    saveJSONObject(projects, projectsJSONFile);
  }
  
  // Get the project manager from the project description
  private String getProjectManager(JSONObject project) {
    
    // Config
    JSONObject pms = config.getJSONObject("projectManagers");
    JSONArray pmNames = pms.getJSONArray("names");
    String desc = project.getString("description");

    // Look through all lines until one designates the project manager
    String[] lines = desc.toLowerCase().split("\n");
    for(int i = 0; i < lines.length; ++i) {
      if(lines[i].length() < 30 && (lines[i].contains(pmWords[0]) || lines[i].contains(pmWords[1]))) {
        // Format the line to remove symbols, extra spaces, and the PM words
        String pm = lines[i];
        for(int k = 0; k < pmWords.length; ++k)
          pm = pm.replace(pmWords[k], "");
        pm = pm.replaceAll("[^\\w\\s]", "");
        pm = pm.trim();
        
        // See if the remaining text matches any of the existing project manager name permutations
        for(int j = 0; j < pmNames.size(); ++j) {
          String name = pmNames.getString(j);
          if(stringContainsIgnoreCase(pm, pms.getJSONObject(name).getJSONArray("permutations"))) {
            return name;
          }
        }
      }
    }
    return "Unknown";
  }
  
  // Calculate name permutations
  private JSONArray getNamePermutations(String name) {
    String[] words = name.toLowerCase().split(" "); 
    JSONArray result = new JSONArray();
    
    result.append(words[0]); // Steven
    if(words.length > 1) {
      result.append(words[1]); // Dunn
      result.append(words[0] + " " + words[1]); // Steven Dunn
      result.append(words[0] + " " + words[1].charAt(0)); // Steven D
      result.append(words[0].charAt(0) + " " + words[1]); // S Dunn
      result.append(words[0].charAt(0) + "" + words[1].charAt(0)); // SD
    }
    return result;
  }
  
  // Add milestones that are part of upcoming projects but before the current day and after the beginning of the current month
  private void addPriorMilestones() {
    
    // Config
    String username = config.getString("userToken");
    String url = config.getString("companyTeamworkURL");
    JSONArray projectIds = projects.getJSONArray("ids");
    JSONArray milestoneIds = milestones.getJSONArray("ids");
    JSONArray milestoneWhitelist = config.getJSONArray("milestoneWhitelist");
    JSONArray milestoneBlacklist = config.getJSONArray("milestoneBlacklist");

    // Get the strings for yesterday and the beginning of the month
    Calendar calendar = Calendar.getInstance();
    calendar.add(Calendar.DAY_OF_YEAR, -1);
    String today = dateParser.format(calendar.getTime());
    calendar.set(Calendar.DAY_OF_MONTH, 0);
    String beginningOfMonth = dateParser.format(calendar.getTime());
    
    // Get all project Ids and put them inside of a string
    String[] projectIdStrings = new String[projectIds.size()];
    for(int i = 0; i < projectIds.size(); ++i)
      projectIdStrings[i] = projectIds.getString(i);
    String projectQuery = String.join(",", projectIdStrings);
    
    // Request all milestones after the beginning of the month and before today that are attached to active projects
    GetRequest get = new GetRequest(url + api + "milestones.json?dueAfter=" + beginningOfMonth + "&dueBefore=" + today + "&projectIds=" + projectQuery);
    get.addUser(username, password);
    get.send();
    
    // Add the milestones to the existing milestones JSON
    JSONObject foundMilestones = parseJSONObject(get.getContent());
    JSONArray milestonesArray = foundMilestones.getJSONArray("milestones");
    for(int i = 0; i < milestonesArray.size(); ++i) {
        JSONObject milestone = milestonesArray.getJSONObject(i);
        if(checkLists(milestone.getString("name"), milestoneWhitelist, milestoneBlacklist)) {
          String id = milestone.getInt("id") + "";
          milestones.setJSONObject(id, milestone);
          milestoneIds.append(id);
        }
    }
    
    saveJSONObject(milestones, milestonesJSONFile); 
  }
    
  private void createSortedJSON() {
    
    sortMilestones();
    
    // Store project managers, projects, then milestones
    projectManagerMilestones = new JSONObject();
    JSONArray projectManagerNames = new JSONArray();
    projectManagerMilestones.setJSONArray("projectManagers", projectManagerNames);

    // For each milestone
    JSONArray milestoneIds = milestones.getJSONArray("ids");
    for(int i = 0; i < milestoneIds.size(); ++i) {
      
      String milestoneId = milestoneIds.getString(i);
      JSONObject milestone = milestones.getJSONObject(milestoneIds.getString(i));
      
      // Get the project manager and project Id from the milestone
      String pmName = milestone.getString("projectManager");
      String projectId = milestone.getInt("projectId") + "";
      
      // Get the project manager from the name
      JSONObject pm = projectManagerMilestones.getJSONObject(pmName);
      if(pm == null) { // If this project manager hasn't been added yet, create the lists
        pm = new JSONObject();
        projectManagerMilestones.setJSONObject(pmName, pm); 
        projectManagerNames.append(pmName);
      }

      // Get the project manager's list of milestones for the current project
      JSONArray pmProjectMilestones = pm.getJSONArray(projectId);
      if(pmProjectMilestones == null) { // If the projects hasn't been added yet, create the lists
        pmProjectMilestones = new JSONArray();
        pm.setJSONArray(projectId, pmProjectMilestones);
        
        // Get the list of Ids for the project
        JSONArray pmProjectIds = pm.getJSONArray("projectIds");
        if(pmProjectIds == null) {
          pmProjectIds = new JSONArray();
          pm.setJSONArray("projectIds", pmProjectIds);
        }
     
        // Only add the project Id if this is the first milestone for this project
        pmProjectIds.append(projectId);
      }
      
      // Add the milestone to the project
      pmProjectMilestones.append(milestoneId);
    }
    
    // Sort the project managers by their number of active projects
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
  
  boolean checkLists(String target, JSONArray whitelist, JSONArray blacklist) {
    return stringContainsIgnoreCase(target, whitelist) &&
          !stringContainsIgnoreCase(target, blacklist);
  }
  
  void sortMilestones() {
    try {
      JSONArray milestoneIDs = milestones.getJSONArray("ids");
      for(int i = 0; i < milestoneIDs.size(); ++i) {
        for(int j = i + 1; j < milestoneIDs.size(); ++j) {
          
          String milestoneIdA = milestoneIDs.getString(i);
          JSONObject milestoneA = milestones.getJSONObject(milestoneIdA);
          Date dateA = dateParser.parse(milestoneA.getString("deadline"));
          
          String milestoneIdB = milestoneIDs.getString(j);
          JSONObject milestoneB = milestones.getJSONObject(milestoneIdB);
          Date dateB = dateParser.parse(milestoneB.getString("deadline"));
          
          if(dateA.after(dateB)) {
            milestoneIDs.setString(i, milestoneIdB);
            milestoneIDs.setString(j, milestoneIdA);
          }
        }
      }
    } catch(Exception e) {
      e.printStackTrace(); 
    }
  }
  
  void sortPMs() {
    JSONArray pms = projectManagerMilestones.getJSONArray("projectManagers");
    for(int i = 0; i < pms.size(); ++i) {
      for(int j = i + 1; j < pms.size(); ++j) {
        
        String pmA = pms.getString(i);
        JSONArray projectIdsA = projectManagerMilestones.getJSONObject(pmA).getJSONArray("projectIds");
        
        String pmB = pms.getString(j);
        JSONArray projectIdsB = projectManagerMilestones.getJSONObject(pmB).getJSONArray("projectIds");
        
        if(projectIdsA.size() < projectIdsB.size()) {
          pms.setString(i, pmB);
          pms.setString(j, pmA);
        }
      }
    }
  }
}
