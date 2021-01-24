class JSONLoader {
  
  private JSONObject temp;
  private JSONArray projectManagerNames;
  public JSONArray getPMs() { return temp.getJSONArray("project-manager"); }
  public JSONArray getMilestones(String pm) { return temp.getJSONObject("milestones").getJSONArray(pm); }
  
  private JSONObject milestones;
  private JSONArray milestoneIDs;
  private JSONObject projects;
  private JSONArray projectIDs;
  
  private String sortedMilestonesJSONFile = "data/sorted_milestones.json";
  private String milestonesJSONFile = "data/milestones.json";
  private String projectsJSONFile = "data/projects.json";
  
  private String url = "https://phaconsulting.teamwork.com/";
  private String username = "";
  private String password = "password";
    
  private String[] pmWords = {"PM", "PROJECT MANAGER"};

  
  public JSONLoader() {
    temp = loadJSONObject(sortedMilestonesJSONFile);
    milestones = loadJSONObject(milestonesJSONFile);
    milestoneIDs = milestones.getJSONArray("ids");
    projects = loadJSONObject(projectsJSONFile);
    projectIDs = projects.getJSONArray("ids");
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
    projectIDs = new JSONArray();
    projects.setJSONArray("ids", projectIDs);
    
    for(int i = 0; i < milestoneIDs.size(); ++i) {
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      String projectID = milestone.getString("project-id");
      
      if(!projects.isNull(projectID)) // Skip if we've downloaded this project ID before
        continue;
      
      GetRequest projectGet = new GetRequest(url + "projects/" + projectID + ".json");
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
    temp = new JSONObject();
    projectManagerNames = new JSONArray();
    temp.setJSONArray("project-managers", projectManagerNames);

    for(int i = 0; i < milestoneIDs.size(); ++i) { // For each milestone
      JSONObject milestone = milestones.getJSONObject(milestoneIDs.getString(i));
      String pmName = milestone.getString("project-manager"); // Get the project manager
      //String milestoneID = milestone.getString("id");
      String projectID = milestone.getString("project-id");
      
      JSONObject pm = temp.getJSONObject(pmName);
      if(pm == null) {
        pm = new JSONObject();
        temp.setJSONObject(pmName, pm); 
        projectManagerNames.append(pmName);
      }
      
      JSONArray pmProjectMilestones = pm.getJSONArray(projectID);
      if(pmProjectMilestones == null) {
        pmProjectMilestones = new JSONArray();
        pm.setJSONArray(projectID, pmProjectMilestones);
        
        JSONArray pmProjectIDs = pm.getJSONArray("ids");
        if(pmProjectIDs == null) {
          pmProjectIDs = new JSONArray();
          pm.setJSONArray("ids", pmProjectIDs);
        }
     
        pmProjectIDs.append(projectID);
      }
            
      pmProjectMilestones.append(milestone);
    }
    
    saveJSONObject(temp, sortedMilestonesJSONFile);
  }
}
