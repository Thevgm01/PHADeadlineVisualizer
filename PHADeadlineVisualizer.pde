import http.requests.*;

boolean sendNewRequest = false;

JSONArray milestones;
JSONObject projects;
String milestonesJSONFile = "data/milestones.json";
String projectsJSONFile = "data/projects.json";
String url = "https://phaconsulting.teamwork.com/";

String[] replaceTargets = {"PM", "PROJECT MANAGER", ".", ":", "-"};
// project manager: xxx
// pm

// AA (Andrew Allen)
// TK
// Randy
// Tim

void setup() {
  size(100, 100);
  //frame.setVisible(false);
    
  if(sendNewRequest) getJSONFiles();
  if(milestones == null) milestones = loadJSONArray(milestonesJSONFile);
  if(projects == null) projects = loadJSONObject(projectsJSONFile);
  
  for(int i = 0; i < milestones.size(); ++i) {
    JSONObject milestone = milestones.getJSONObject(i);
    setProjectManager(milestone);    
  }
  saveJSONArray(milestones, milestonesJSONFile);
}

void getJSONFiles() {
  String username = loadStrings("API_Token.txt")[0];
  String password = "password";
    
  GetRequest get = new GetRequest(url + "milestones.json?find=upcoming");
  get.addUser(username, password);
  //get.addHeader("find", "upcoming");
  get.send();
  
  JSONObject milestonesJSON = parseJSONObject(get.getContent());
  milestones = milestonesJSON.getJSONArray("milestones");
  saveJSONArray(milestones, milestonesJSONFile);
      
  JSONObject projects = new JSONObject();
  for(int i = 0; i < milestones.size(); ++i) {
    JSONObject milestone = milestones.getJSONObject(i);
    String id = milestone.getString("project-id");
    
    if(projects.getJSONObject(id) != null) // skip if we've already downloaded this project ID
      continue;
    
    GetRequest projectGet = new GetRequest(url + "projects/" + id + ".json");
    projectGet.addUser(username, password);
    println(url + "projects/" + id + ".json");
    projectGet.send();
    
    JSONObject project = parseJSONObject(projectGet.getContent());
    projects.setJSONObject(id, project);
  }
  saveJSONObject(projects, projectsJSONFile);
}

void setProjectManager(JSONObject milestone) {
  if(milestone.getString("project-manager") != null)
    return;
  
  String id = milestone.getString("project-id");
  JSONObject project = projects.getJSONObject(id);
  JSONObject projectInfo = project.getJSONObject("project");
  String desc = projectInfo.getString("description");
  
  String pm = "UNKNOWN";
  String[] lines = desc.toUpperCase().split("\n");
  for(int j = 0; j < lines.length; ++j) {
    if(lines[j].length() < 30 && (lines[j].contains("PM") || lines[j].contains("PROJECT MANAGER"))) {
      pm = lines[j];
      for(int k = 0; k < replaceTargets.length; ++k) {
        pm = pm.replace(replaceTargets[k], "");
      }
      pm = pm.trim();
      break;
    }
  }
  milestone.setString("project-manager", pm);
}

void draw() {
  background(0); 
}
