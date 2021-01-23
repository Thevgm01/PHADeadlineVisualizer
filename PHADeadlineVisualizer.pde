import http.requests.*;
import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

final boolean SEND_NEW_REQUESTS = false;

JSONLoader jsons;

void setup() {
  size(500, 500);
  //frame.setVisible(false);
  background(255);
  fill(255, 0, 0);
  
  String username = loadStrings("API_Token.txt")[0];
  jsons = new JSONLoader(username);

  int yOffset = 5;

  Calendar cal = Calendar.getInstance();
  try {
    SimpleDateFormat parser = new SimpleDateFormat("yyyyMMdd");
    JSONArray pms = jsons.getPMs();
    for(int i = 0; i < pms.size(); ++i) {
      String pm = pms.getString(i); 
      JSONArray milestones = jsons.getMilestones(pm);
      for(int j = 0; j < milestones.size(); ++j) {
        JSONObject milestone = milestones.getJSONObject(j);
        
        String deadline = milestone.getString("deadline");
        Date deadlineDate = parser.parse(deadline);
        cal.setTime(deadlineDate);
        
        int x = cal.get(Calendar.DAY_OF_YEAR) * 5;
        circle(x, yOffset, 5);
        
        yOffset += 5;
        //println(cal.get(Calendar.DAY_OF_YEAR));
      }
    }
  } catch (java.text.ParseException e) {
    e.printStackTrace(); 
  }
}
