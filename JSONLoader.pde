class JSONLoader {
  
  private JSONObject projectManagersAndProjects;
  public JSONArray getPMs() { return projectManagersAndProjects.getJSONArray(pmKey); }
  public JSONArray getMilestones(String pm) { return projectManagersAndProjects.getJSONObject(msKey).getJSONArray(pm); }
  private JSONArray milestones;
  private JSONObject projects;
  
  private String sortedMilestonesJSONFile = "data/sorted_milestones.json";
  private String milestonesJSONFile = "data/milestones.json";
  private String projectsJSONFile = "data/projects.json";
  
  private String url = "https://phaconsulting.teamwork.com/";
  private String username = "";
  private String password = "password";
  
  private String idKey = "project-id";
  private String msKey = "milestones";
  private String pmKey = "project-manager";
  
  private String[] pmWords = {"PM", "PROJECT MANAGER"};

  
  public JSONLoader() {
    projectManagersAndProjects = loadJSONObject(sortedMilestonesJSONFile);
    milestones = loadJSONArray(milestonesJSONFile);
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
    GetRequest get = new GetRequest(url + "milestones.json?find=upcoming");
    get.addUser(username, password);
    get.send();
    
    JSONObject milestonesJSON = parseJSONObject(get.getContent());
    milestones = milestonesJSON.getJSONArray(msKey);
    saveJSONArray(milestones, milestonesJSONFile);
  }
  
  // Get the project associated with each milestone
  private void downloadProjectsJSON() {
    projects = new JSONObject();
    for(int i = 0; i < milestones.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(i);
      String id = milestone.getString(idKey);
      
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
    for(int i = 0; i < milestones.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(i);
      milestone.setString(pmKey, getProjectManager(milestone));
    }
    saveJSONArray(milestones, milestonesJSONFile);
  }
  
  private String getProjectManager(JSONObject milestone) {
    if(!milestone.isNull(pmKey))
      return milestone.getString(pmKey);
    
    String id = milestone.getString(idKey);
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
    for(int i = 0; i < milestones.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(i);
      String pm = milestone.getString(pmKey);
      
      JSONArray pmMilestones = sortedMilestones.getJSONArray(pm);
      if(pmMilestones == null) {
        projectManagers.append(pm);
        pmMilestones = new JSONArray();
        sortedMilestones.setJSONArray(pm, pmMilestones);
      }
      pmMilestones.append(milestone);
    }
    projectManagersAndProjects.setJSONArray(pmKey, projectManagers);
    projectManagersAndProjects.setJSONObject(msKey, sortedMilestones);
    saveJSONObject(projectManagersAndProjects, sortedMilestonesJSONFile);
  }
}
