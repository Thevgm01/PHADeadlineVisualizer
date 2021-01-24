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
  jsons = new JSONLoader(username);

  int yOffset = 5;

  Calendar cal = Calendar.getInstance();
  Calendar startCal = Calendar.getInstance();
  Calendar endCal = Calendar.getInstance();
  try {
    SimpleDateFormat creationParser = new SimpleDateFormat("yyyy-MM-dd");
    SimpleDateFormat deadlineParser = new SimpleDateFormat("yyyyMMdd");
    JSONArray pms = jsons.getPMs();
    for(int i = 0; i < pms.size(); ++i) {
      String pm = pms.getString(i); 
      JSONArray milestones = jsons.getMilestones(pm);
      for(int j = 0; j < milestones.size(); ++j) {
        JSONObject milestone = milestones.getJSONObject(j);
        
        String creation = milestone.getString("created-on");
        creation = creation.substring(0, creation.indexOf("T"));
        Date creationDate = creationParser.parse(creation);
        startCal.setTime(creationDate);
        int startX = startCal.get(Calendar.DAY_OF_YEAR) * 5;
        
        String deadline = milestone.getString("deadline");
        Date deadlineDate = deadlineParser.parse(deadline);
        endCal.setTime(deadlineDate);
        int endX = endCal.get(Calendar.DAY_OF_YEAR) * 5;
        
        if(startCal.get(Calendar.YEAR) < cal.get(Calendar.YEAR)) {
          startX = 5; 
        }

        if(endCal.get(Calendar.YEAR) > cal.get(Calendar.YEAR)) {
          endX = 365 * 5; 
        }
        
        line(startX, yOffset, endX, yOffset);
        //circle(x, yOffset, 5);
        
        yOffset += 5;
        //println(cal.get(Calendar.DAY_OF_YEAR));
      }
    }
  } catch (java.text.ParseException e) {
    e.printStackTrace(); 
  }
}
