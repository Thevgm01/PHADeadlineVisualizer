import http.requests.*;
import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

final boolean SEND_NEW_REQUESTS = false;

JSONLoader jsons;

void setup() {
  size(1000, 500);
  //frame.setVisible(false);
  background(255);
  fill(255, 0, 0);
  
  String username = loadStrings("API_Token.txt")[0];
  jsons = new JSONLoader();

  textSize(10);
  textAlign(CENTER, BOTTOM);
  int yOffset = 5;
  int startTextYOffset = 0;
  int increase = 15;

  Calendar cal = Calendar.getInstance();
  Calendar startCal = Calendar.getInstance();
  Calendar endCal = Calendar.getInstance();
  try {
    SimpleDateFormat creationParser = new SimpleDateFormat("yyyy-MM-dd");
    SimpleDateFormat deadlineParser = new SimpleDateFormat("yyyyMMdd");
    
    JSONArray pms = jsons.getPMs();
    for(int i = 0; i < pms.size(); ++i) {
      String pm = pms.getString(i); 
      JSONArray projects = jsons.getProjects(pm);
      int textYOffset = startTextYOffset;
      for(int j = 0; j < projects.size(); ++j) {
        String projectID = projects.getString(j);
        JSONArray milestones = jsons.getMilestones(pm, projectID);
        
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
          
          if(currentDeadline != null && deadline.after(currentDeadline)) {
            circle(endX, yOffset, 10); 
          }
          text(milestone.getString("title"), endX, yOffset + textYOffset);
          textYOffset += increase;
          
          currentDeadline = deadline;
        }
        yOffset += increase + textYOffset;
      }
    }
  } catch (java.text.ParseException e) {
    e.printStackTrace(); 
  }
}
