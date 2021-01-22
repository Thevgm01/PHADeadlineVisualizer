import http.requests.*;

boolean sendNewRequest = true;

JSONObject sortedMilestones;
JSONArray milestones;
JSONObject projects;
String sortedMilestonesJSONFile = "data/sorted_milestones.json";
String milestonesJSONFile = "data/milestones.json";
String projectsJSONFile = "data/projects.json";

String url = "https://phaconsulting.teamwork.com/";
String username = "";
String password = "password";

String idKey = "project-id";
String pmKey = "project-manager";

String[] pmWords = {"PM", "PROJECT MANAGER"};
// project manager: xxx
// pm

// AA (Andrew Allen)
// TK
// Randy
// Tim

void setup() {
  size(100, 100);
  //frame.setVisible(false);
  
  username = loadStrings("API_Token.txt")[0];
    
  if(sendNewRequest) {
    downloadMilestonesJSON();
    downloadProjectsJSON();
    setProjectManagers();
  } else {
    milestones = loadJSONArray(milestonesJSONFile);
    projects = loadJSONObject(projectsJSONFile);
  }
  
  sortByProjectManager();
}

// Get all upcoming milestones
void downloadMilestonesJSON() {    
  GetRequest get = new GetRequest(url + "milestones.json?find=upcoming");
  get.addUser(username, password);
  get.send();
  
  JSONObject milestonesJSON = parseJSONObject(get.getContent());
  milestones = milestonesJSON.getJSONArray("milestones");
  saveJSONArray(milestones, milestonesJSONFile);
}

// Get the project associated with each milestone
void downloadProjectsJSON() {
  projects = new JSONObject();
  for(int i = 0; i < milestones.size(); ++i) {
    JSONObject milestone = milestones.getJSONObject(i);
    String id = milestone.getString(idKey);
    
    if(projects.getJSONObject(id) != null) // Skip if we've downloaded this project ID before
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

void setProjectManagers() {
  for(int i = 0; i < milestones.size(); ++i) {
    JSONObject milestone = milestones.getJSONObject(i);
    milestone.setString(pmKey, getProjectManager(milestone));
  }
  saveJSONArray(milestones, milestonesJSONFile);
}

void sortByProjectManager() {
  sortedMilestones = new JSONObject();
  for(int i = 0; i < milestones.size(); ++i) {
    JSONObject milestone = milestones.getJSONObject(i);
    String pm = milestone.getString(pmKey);
    
    JSONArray pmMilestones = sortedMilestones.getJSONArray(pm);
    if(pmMilestones == null) {
      pmMilestones = new JSONArray();
      sortedMilestones.setJSONArray(pm, pmMilestones);
    }
    pmMilestones.append(milestone);
  }
  saveJSONObject(sortedMilestones, sortedMilestonesJSONFile);
}

String getProjectManager(JSONObject milestone) {
  String pm = milestone.getString(pmKey);
  if(pm != null)
    return pm;
  
  String id = milestone.getString(idKey);
  JSONObject project = projects.getJSONObject(id);
  JSONObject projectInfo = project.getJSONObject("project");
  String desc = projectInfo.getString("description");
  
  String[] lines = desc.toUpperCase().split("\n");
  for(int j = 0; j < lines.length; ++j) {
    if(lines[j].length() < 30 && (lines[j].contains(pmWords[0]) || lines[j].contains(pmWords[1]))) {
      pm = lines[j];
      for(int k = 0; k < pmWords.length; ++k)
        pm = pm.replace(pmWords[k], "");
      pm = pm.replaceAll("[^\\w\\s]", "");
      pm = pm.trim();
      return pm;
    }
  }
  return "UNKNOWN";
}

void draw() {
  background(0); 
}
