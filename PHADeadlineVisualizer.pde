import http.requests.*;
import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

final boolean SEND_NEW_REQUESTS = false;

JSONLoader jsons;

int maxHeight = 0;

void setup() {
  size(1000, 500);
  colorMode(HSB);
  //frame.setVisible(false);
  background(255);
  noStroke();
  
  String username = loadStrings("API_Token.txt")[0];
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

  Calendar cal = Calendar.getInstance();
  Calendar startCal = Calendar.getInstance();
  Calendar endCal = Calendar.getInstance();
  try {
    SimpleDateFormat creationParser = new SimpleDateFormat("yyyy-MM-dd");
    SimpleDateFormat deadlineParser = new SimpleDateFormat("yyyyMMdd");
    
    JSONArray pms = jsons.getPMs();
    for(int i = 0; i < pms.size(); ++i) {
      fill(color(mainHue, 255, 100));
      mainHue += 50;
      
      String pm = pms.getString(i); 
      
      textAlign(LEFT, TOP);
      text(pm, 0, yOffset);
      yOffset += increase; 
      
      JSONArray projects = jsons.getProjects(pm);
      int textYOffset = startTextYOffset;
      for(int j = 0; j < projects.size(); ++j) {
        String projectID = projects.getString(j);
        JSONArray milestones = jsons.getMilestones(pm, projectID);
        
        textAlign(LEFT, TOP);
        text(milestones.getJSONObject(0).getString("project-name"), 20, yOffset);
        textAlign(CENTER, TOP);
        yOffset += increase;
        circleOffset = yOffset - circleSize;
        
        Date smallestDeadline = null, currentDeadline = null;
        for(int k = 0; k < milestones.size(); ++k) {
          JSONObject milestone = milestones.getJSONObject(k);
            
          String creationText = milestone.getString("created-on");
          creationText = creationText.substring(0, creationText.indexOf("T"));
          Date creation = creationParser.parse(creationText);
          startCal.setTime(creation);
          int startX = startCal.get(Calendar.DAY_OF_YEAR) * increase;
          
          String deadlineText = milestone.getString("deadline");
          Date deadline = deadlineParser.parse(deadlineText);
          endCal.setTime(deadline);
          int endX = endCal.get(Calendar.DAY_OF_YEAR) * increase;
          
          if(startCal.get(Calendar.YEAR) < cal.get(Calendar.YEAR)) {
            startX = 0; 
          } else if(endCal.get(Calendar.YEAR) > cal.get(Calendar.YEAR)) {
            endX = 365 * increase; 
          }
          
          //line(startX, yOffset, endX, yOffset);
          //circle(x, yOffset, 5);
          
          //println(cal.get(Calendar.DAY_OF_YEAR));
          
          if(smallestDeadline == null) {
            smallestDeadline = creation; 
          }
          
          //if(currentDeadline != null && deadline.after(currentDeadline)) {
            circle(endX, circleOffset, circleSize); 
          //}
          text(milestone.getString("title"), endX, yOffset);
          yOffset += increase;
          
          currentDeadline = deadline;
        }
      }
    }
  } catch (java.text.ParseException e) {
    e.printStackTrace(); 
  }
  
  maxHeight = yOffset - height + increase;
}
