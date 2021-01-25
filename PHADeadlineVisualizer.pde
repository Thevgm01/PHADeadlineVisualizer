import http.requests.*;
import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

final boolean SEND_NEW_REQUESTS = false;

JSONLoader jsons;

int maxHeight = 0;

SimpleDateFormat creationParser, deadlineParser;
Calendar creationCal, deadlineCal;

void setup() {
  size(1000, 500);
  colorMode(HSB);
  //frame.setVisible(false);
  background(255);
  noStroke();
  
  creationParser = new SimpleDateFormat("yyyy-MM-dd");
  deadlineParser = new SimpleDateFormat("yyyyMMdd");
  creationCal = Calendar.getInstance();
  deadlineCal = Calendar.getInstance();
  
  String username = loadStrings("API_Token.txt")[0];
  //jsons = new JSONLoader(username);
  jsons = new JSONLoader();
}

void draw() {
  background(255);
  translate(0, -map(mouseY, 0, height, 0, maxHeight));
  
  int mainHue = 0;
  
  textSize(10);
  int yOffset = 5;
  int circleOffset = 5;
  int startTextYOffset = 0;
  int increase = 15;
  int circleSize = 10;

  textAlign(CENTER, TOP);
  for(int i = 1; i < 365; ++i) {
    text(i, (i + 1) * increase, 0);
  }
  
  yOffset += 10;

  JSONArray pms = jsons.getPMs();
  for(int i = 0; i < pms.size(); ++i) {
    fill(color(mainHue, 255, 100));
    mainHue += 50;
    
    String pm = pms.getString(i); 
        
    JSONArray projects = jsons.getProjects(pm);
    int textYOffset = startTextYOffset;
    
    String numProjects = projects.size() + " active project";
    if(projects.size() > 1) numProjects += "s";
    
    textAlign(LEFT, TOP);
    text(pm + " - " + numProjects, 0, yOffset);
    yOffset += increase; 
    
    for(int j = 0; j < projects.size(); ++j) {
      String projectID = projects.getString(j);
      JSONArray milestones = jsons.getMilestones(pm, projectID);
      
      //drawProjectLine();
      
      textAlign(LEFT, TOP);
      text(milestones.getJSONObject(0).getString("project-name"), 20, yOffset);
      textAlign(CENTER, TOP);
      yOffset += increase;
      circleOffset = yOffset - circleSize;
      
      int startX = 0;
            
      Date smallestDeadline = null, currentDeadline = null;
      for(int k = 0; k < milestones.size(); ++k) {
        JSONObject milestone = milestones.getJSONObject(k);
                    
        if(k == 0) {
          setCalendar(creationCal, milestone);
          startX = creationCal.get(Calendar.DAY_OF_YEAR) * increase; 
        }
                    
        setCalendar(deadlineCal, milestone);
        int endX = deadlineCal.get(Calendar.DAY_OF_YEAR) * increase;
        /*
        if(creationCal.get(Calendar.YEAR) < cal.get(Calendar.YEAR)) {
          startX = 0; 
        }
        
        if(deadlineCal.get(Calendar.YEAR) > cal.get(Calendar.YEAR)) {
          endX = 365 * increase; 
        }
        */
        //line(startX, yOffset, endX, yOffset);
        //circle(x, yOffset, 5);
        
        //println(cal.get(Calendar.DAY_OF_YEAR));
       
        
        //if(currentDeadline != null && deadline.after(currentDeadline)) {
          circle(endX, circleOffset, circleSize); 
        //}
        text(milestone.getString("title"), endX, yOffset);
        yOffset += increase;
        
      }
    }
  }
  
  maxHeight = yOffset - height + increase;
  if(maxHeight < 0) maxHeight = 0;
}

void setCalendar(Calendar cal, JSONObject milestone) {
  try {
    if(cal == creationCal) {
      String date = milestone.getString("created-on");
      date = date.substring(0, date.indexOf("T"));
      cal.setTime(creationParser.parse(date));
    } else if(cal == deadlineCal) {
      String date = milestone.getString("deadline");
      cal.setTime(deadlineParser.parse(date));
    }
  } catch(java.text.ParseException e) {
    e.printStackTrace(); 
  }
}

void drawProjectLine(JSONArray milestones) {
  
}
