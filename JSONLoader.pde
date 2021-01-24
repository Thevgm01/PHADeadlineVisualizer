class JSONLoader {
  
  private JSONObject projectManagersAndProjects;
  public JSONArray getPMs() { return projectManagersAndProjects.getJSONArray("project-manager"); }
  public JSONArray getMilestones(String pm) { return projectManagersAndProjects.getJSONObject("milestones").getJSONArray(pm); }
  private JSONObject milestones;
  private JSONObject projects;
  private JSONArray milestoneIDs;
  
  private String sortedMilestonesJSONFile = "data/sorted_milestones.json";
  private String milestonesJSONFile = "data/milestones.json";
  private String projectsJSONFile = "data/projects.json";
  
  private String url = "https://phaconsulting.teamwork.com/";
  private String username = "";
  private String password = "password";
    
  private String[] pmWords = {"PM", "PROJECT MANAGER"};

  
  public JSONLoader() {
    projectManagersAndProjects = loadJSONObject(sortedMilestonesJSONFile);
    milestones = loadJSONObject(milestonesJSONFile);
    milestoneIDs = milestones.getJSONArray("ids");
    projects = loadJSONObject(projectsJSONFile);
  }
  
  public JSONLoader(String username) {
    this.username = username;
    downloadMilestonesJSON();
    downloadProjectsJSON();
    setProjectManagers();
    sortByProjectManager();
  }

  // Get all upcoming milestones
  private void downloadMilestonesJSON() {    
    milestones = new JSONObject();
    milestoneIDs = new JSONArray();
    milestones.setJSONArray("ids", milestoneIDs);
    
    GetRequest get = new GetRequest(url + "milestones.json?find=upcoming");
    get.addUser(username, password);
    get.send();
    
    JSONObject milestonesJSON = parseJSONObject(get.getContent());
    JSONArray milestonesArray = milestonesJSON.getJSONArray("milestones");
    for(int i = 0; i < milestonesArray.size(); ++i) {
      JSONObject milestone = milestonesArray.getJSONObject(i);
      String id = milestone.getString("id");
      milestones.setJSONObject(id, milestone);
      milestoneIDs.append(id);
    }
    saveJSONObject(milestones, milestonesJSONFile);
  }
  
  // Get the project associated with each milestone
  private void downloadProjectsJSON() {
    projects = new JSONObject();
    
    for(int i = 0; i < milestoneIDs.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      String id = milestone.getString("project-id");
      
      if(!projects.isNull(id)) // Skip if we've downloaded this project ID before
        continue;
      
      GetRequest projectGet = new GetRequest(url + "projects/" + id + ".json");
      projectGet.addUser(username, password);
      //println(url + "projects/" + id + ".json");
      projectGet.send();
      
      JSONObject project = parseJSONObject(projectGet.getContent());
      projects.setJSONObject(id, project);
    }
    saveJSONObject(projects, projectsJSONFile); 
  }
  
  private void setProjectManagers() {
    for(int i = 0; i < milestoneIDs.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      milestone.setString("project-manager", getProjectManager(milestone));
    }
    saveJSONObject(milestones, milestonesJSONFile);
  }
  
  private String getProjectManager(JSONObject milestone) {
    if(!milestone.isNull("project-manager"))
      return milestone.getString("project-manager");
    
    String id = milestone.getString("project-id");
    JSONObject project = projects.getJSONObject(id);
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
  
  private void sortByProjectManager() {
    projectManagersAndProjects = new JSONObject();
    JSONArray projectManagers = new JSONArray();
    JSONObject sortedMilestones = new JSONObject();

    for(int i = 0; i < milestoneIDs.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i)); // For each milestone
      String pm = milestone.getString("project-manager"); // Get the project manager
      
      JSONObject pmMilestones = sortedMilestones.getJSONArray(pm);
      JSONArray pmMilestonIDs = 
      if(pmMilestones == null) { // See if this is the first project for this PM so far
        projectManagers.append(pm); // If yes, add the PM to the list
        pmMilestones = new JSONArray();
        sortedMilestones.setJSONArray(pm, pmMilestones);
      }
      pmMilestones.append(milestone);
    }
    projectManagersAndProjects.setJSONArray("project-manager", projectManagers);
    projectManagersAndProjects.setJSONObject("milestones", sortedMilestones);
    saveJSONObject(projectManagersAndProjects, sortedMilestonesJSONFile);
  }
}
