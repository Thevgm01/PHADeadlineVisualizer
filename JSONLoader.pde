

class JSONLoader {
  
  private JSONObject sorted;
  
  public JSONArray getPMs() { return sorted.getJSONArray("projectManagers"); }
  public JSONObject getPM(String pm) { return sorted.getJSONObject(pm); }
  public JSONObject getMilestone(int index) { return everything.getJSONArray("milestones").getJSONObject(index); }
  public String getProjectName(String projectId) { return everything.getJSONObject("projects").getJSONObject(projectId).getString("name"); }
  public Calendar getEarliest() { return earliestMilestone; }
  public Calendar getLatest() { return latestMilestone; }

  public int status = 0;

  private JSONObject config;
  private JSONObject everything;
  
  private String configJSONFile = "config.json";
  
  private String url = "";
  private String username = "";
  private String password = "password";
  private String api = "/projects/api/v3/";

  private String[] pmWords = {"pm", "project manager"};
  
  private Calendar earliestMilestone, latestMilestone;

  public JSONLoader() {
    try {
      earliestMilestone = Calendar.getInstance();
      latestMilestone = Calendar.getInstance();
      
      loadConfig();
      //downloadMilestonesJSON();
      //downloadAbsencesJSON();
      //addPriorMilestones();
      everything = loadJSONObject("everything.json");
      createSortedJSON();
      status = 1;
            
      saveJSONObject(everything, "everything.json");
      saveJSONObject(sorted, "sorted.json");
    } catch(Exception e) {
      e.printStackTrace();
      status = -1; 
    }
  }
  
  private void loadConfig() {
    config = loadJSONObject(configJSONFile);
    url = config.getString("companyTeamworkURL");
    username = config.getString("apiKey");
  }
  
  // Get all upcoming milestones and their projects
  private void downloadMilestonesJSON() {
    
    // Config
    JSONArray milestoneWhitelist = config.getJSONArray("milestoneWhitelist");
    JSONArray milestoneBlacklist = config.getJSONArray("milestoneBlacklist");
    
    // Initialize JSON object
    everything = new JSONObject();
    JSONArray allMilestones = new JSONArray();
    JSONObject allProjects = new JSONObject();
    everything.setJSONArray("milestones", allMilestones);
    everything.setJSONObject("projects", allProjects);
    
    // Download all upcoming milestones (with pagination)
    int page = 0;
    boolean hasMore = true;
    while(hasMore) {
      GetRequest get = new GetRequest(url + api + "milestones.json?include=projects&status=upcoming&page=" + ++page);

      get.addUser(username, password);
      get.send();
    
      JSONObject requestedMilestones = parseJSONObject(get.getContent());
      JSONArray downloadedMilestones = requestedMilestones.getJSONArray("milestones");
      JSONObject downloadedProjects = requestedMilestones.getJSONObject("included").getJSONObject("projects");
      
      // Go through each downloaded milestone
      for(int i = 0; i < downloadedMilestones.size(); ++i) {
        JSONObject milestone = downloadedMilestones.getJSONObject(i);
        // If the milestone's name is in the whitelist and isn't in the blacklist
        if(checkLists(milestone.getString("name"), milestoneWhitelist, milestoneBlacklist)) {
          
          String projectId = milestone.getInt("projectId") + "";
          if(allProjects.isNull(projectId)) {
            JSONObject project = downloadedProjects.getJSONObject(projectId);
            project.setString("projectManager", getProjectManager(project));
            allProjects.setJSONObject(projectId, project);
          }
          
          allMilestones.append(milestone);
        }
      }
      
      hasMore = requestedMilestones.getJSONObject("meta").getJSONObject("page").getBoolean("hasMore");
    }
        
    //saveJSONObject(allMilestonesAndProjects, "everything.json");
  } // downloadMilestonesJSON
  
  // Get the project manager from the project description
  private String getProjectManager(JSONObject project) {
    
    // Config
    JSONObject pms = config.getJSONObject("projectManagers");
    JSONArray pmNames = pms.getJSONArray("names");
    String desc = project.getString("description");
    
    // Set the name permutations for the config
    if(pms.getJSONObject(pmNames.getString(0)).isNull("permutations")) {
      for(int i = 0; i < pmNames.size(); ++i) {
        String name = pmNames.getString(i);
        pms.getJSONObject(name).setJSONArray("permutations", getNamePermutations(name));
      }
    }

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
  } // getProjectManager
    
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
    JSONArray projectIds = everything.getJSONObject("projects").getJSONArray("ids");
    JSONArray milestoneIds = everything.getJSONArray("ids");
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
        everything.setJSONObject(id, milestone);
        milestoneIds.append(id);
      }
    }
  } // addPriorMilestones
  
  private void downloadAbsencesJSON() {
    
    Calendar calendar = Calendar.getInstance();
    String today = dateParser.format(calendar.getTime());
    calendar.set(Calendar.YEAR, calendar.get(Calendar.YEAR) + 1);
    String end = dateParser.format(calendar.getTime());
    
    // Initialize JSON object
    JSONArray absences = new JSONArray();
    everything.setJSONArray("absences", absences);
    
    int page = 0;
    boolean hasMore = true;
    while(hasMore) {
      GetRequest get = new GetRequest(url + api + "calendar/events.json?startDate=" + today + "&endDate=" + end + "&page=" + ++page);
      get.addUser(username, password);
      get.send();
    
      JSONObject requestedEvents = parseJSONObject(get.getContent());
      JSONArray downloadedEvents = requestedEvents.getJSONArray("calendarEvents");
      
      // Add found events to a JSON array if their type is a 'vacation'
      for(int i = 0; i < downloadedEvents.size(); ++i) {
        JSONObject event = downloadedEvents.getJSONObject(i);
        //102003 for 'vacation'
        if(!event.isNull("type") && event.getJSONObject("type").getInt("id") == 102003) {
          absences.append(event);
        }
      }
      
      hasMore = requestedEvents.getJSONObject("meta").getJSONObject("page").getBoolean("hasMore");
    }
  }
  
  private void createSortedJSON() {
    
    JSONArray allMilestones = everything.getJSONArray("milestones");
    JSONObject allProjects = everything.getJSONObject("projects");
    
    // Store project managers, projects, then milestones
    sorted = new JSONObject();
    sorted.setJSONArray("projectManagers", new JSONArray());

    // For each milestone
    JSONArray milestones = everything.getJSONArray("milestones");
    for(int i = 0; i < milestones.size(); ++i) {
      
      JSONObject milestone = allMilestones.getJSONObject(i);
      String projectId = milestone.getInt("projectId") + "";
      JSONObject project = allProjects.getJSONObject(projectId);
      String projectManager = project.getString("projectManager");
      
      if(i == 0 || i == milestones.size() - 1) {
        try {
          Date deadline = dateParser.parse(milestone.getString("deadline"));
          if(i == 0) earliestMilestone.setTime(deadline); 
          else       latestMilestone.setTime(deadline); 
        } catch(Exception e) {
          e.printStackTrace(); 
        }
      }
      
      JSONObject pm = sorted.getJSONObject(projectManager);
      // Add the project manager, if they don't exist
      if(pm == null) {
        pm = new JSONObject();
        pm.setInt("numProjects", 0);
        pm.setInt("numMilestones", 0);
        pm.setString("color", config.getJSONObject("projectManagers").getJSONObject(projectManager).getString("color"));
        
        JSONObject pmProjects = new JSONObject();
        pmProjects.setJSONArray("ids", new JSONArray());
        pm.setJSONObject("projects", pmProjects);
        
        sorted.setJSONObject(projectManager, pm);
        sorted.getJSONArray("projectManagers").append(projectManager);
      }
      
      // Add the project, if it doesn't exist
      JSONObject pmProjects = pm.getJSONObject("projects");
      JSONArray pmProject = pmProjects.getJSONArray(projectId);
      if(pmProject == null) {
        pmProject = new JSONArray();
        pmProjects.getJSONArray("ids").append(projectId);
        pmProjects.setJSONArray(projectId, pmProject);
        pm.setInt("numProjects", pm.getInt("numProjects") + 1);
      }
      
      // Add the milestone
      pmProject.append(i);
      pm.setInt("numMilestones", pm.getInt("numMilestones") + 1);
    }
    
    // Sort the project managers by their number of active projects
    sortPMs();
  } // createSortedJSON

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

  void sortPMs() {
    JSONArray pms = sorted.getJSONArray("projectManagers");
    for(int i = 0; i < pms.size(); ++i) {
      for(int j = i + 1; j < pms.size(); ++j) {
        
        String nameA = pms.getString(i);
        String nameB = pms.getString(j);
        JSONObject pmA = sorted.getJSONObject(nameA);
        JSONObject pmB = sorted.getJSONObject(nameB);
                
        int projectDiff = pmA.getInt("numProjects") - pmB.getInt("numProjects");
        int milestoneDiff = pmA.getInt("numMilestones") - pmB.getInt("numMilestones");
        
        // First sort by number of projects descending, then number of milestones descending, then name alphabetical
        if(projectDiff < 0 ||
          (projectDiff == 0 && (milestoneDiff < 0 ||
                               (milestoneDiff == 0 && nameA.compareTo(nameB) < 0)))) {
          pms.setString(i, nameB);
          pms.setString(j, nameA);
        }
      }
    }
  }
  
}
