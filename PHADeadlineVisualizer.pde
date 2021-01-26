import http.requests.*;
import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

final boolean SEND_NEW_REQUESTS = false;

JSONLoader jsons;

int maxHeight = 0;

String[] monthNames = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"};
SimpleDateFormat creationParser, deadlineParser;
Calendar curCal, creationCal, deadlineCal;

void setup() {
  size(1000, 500);
  colorMode(HSB);
  //frame.setVisible(false);
  background(255);
  noStroke();
  
  rectMode(CENTER);
  
  creationParser = new SimpleDateFormat("yyyy-MM-dd");
  deadlineParser = new SimpleDateFormat("yyyyMMdd");
  curCal = Calendar.getInstance();
  creationCal = Calendar.getInstance();
  deadlineCal = Calendar.getInstance();
  
  String username = loadStrings("API_Token.txt")[0];
  jsons = new JSONLoader();
}

void draw() {
  background(255);
  translate(0, -map(mouseY, 0, height, 0, maxHeight));
  
  int mainHue = 0;
  
  float textSize = 10;
  textSize(textSize);
  int yOffset = 5;
  int circleOffset = 5;
  int startTextYOffset = 0;
  int increase = 15;
  int circleSize = 10;

  float longestProjectNameWidth = 0;
  
  yOffset += 10 + increase;
  int startY = yOffset;
  JSONArray pms = jsons.getPMs();
  
  // FOR EACH TYPE
  for(int type = 0; type < 4; ++type) {
    yOffset = startY;
    
    // FOR EACH PROJECT MANAGER
    for(int i = 0; i < pms.size(); ++i) {
      //fill(color(mainHue, 255, 100));
      //mainHue += 50;
      
      String pm = pms.getString(i); 
      JSONArray projects = jsons.getProjects(pm);
      
      if(type == 0) {
        String numProjects = projects.size() + " active project";
        if(projects.size() > 1) numProjects += "s";
        
        textAlign(LEFT, TOP);
        text(pm + " - " + numProjects, 0, yOffset);
      }
      
      yOffset += increase; 
      
      // FOR EACH PROJECT
      for(int j = 0; j < projects.size(); ++j) {
        String projectID = projects.getString(j);
        JSONArray milestones = jsons.getMilestones(pm, projectID);
             
        String projectName = milestones.getJSONObject(0).getString("project-name");
        float w = textWidth(projectName);
                
        if(type == 0) {
          textAlign(LEFT, TOP);
          if(w > longestProjectNameWidth)
            longestProjectNameWidth = w;
          text(projectName, 20, yOffset);
          textAlign(CENTER, TOP);
        }
        
        yOffset += increase;
        circleOffset = yOffset - circleSize + 1;
        
        if(type == 1) {
          setCalendar(creationCal, milestones.getJSONObject(0));
          setCalendar(deadlineCal, milestones.getJSONObject(milestones.size() - 1));
          
          float startX = longestProjectNameWidth + 20 + creationCal.get(Calendar.DAY_OF_YEAR) * increase;
          float endX = longestProjectNameWidth + 20 + deadlineCal.get(Calendar.DAY_OF_YEAR) * increase;
          if(creationCal.get(Calendar.YEAR) < curCal.get(Calendar.YEAR))
            startX = longestProjectNameWidth + increase + 20; 
          if(deadlineCal.get(Calendar.YEAR) > curCal.get(Calendar.YEAR))
            endX = curCal.getActualMaximum(Calendar.DAY_OF_YEAR) * increase; 
          
          stroke(0);
          strokeWeight(1);
          line(w + increase * 2, circleOffset, endX, circleOffset);
        }
        
        // FOR EACH MILESTONE
        for(int k = 0; k < milestones.size(); ++k) {
          JSONObject milestone = milestones.getJSONObject(k);
          
          float endX;
          if(k < 0) {
            setCalendar(creationCal, milestone);
            endX = longestProjectNameWidth + 20 + creationCal.get(Calendar.DAY_OF_YEAR) * increase;
          } else {
            setCalendar(deadlineCal, milestone);
            endX = longestProjectNameWidth + 20 + deadlineCal.get(Calendar.DAY_OF_YEAR) * increase;
          }
          
          String title = milestone.getString("title");
          
          switch(type) {
            case 1:
              stroke(255);
              strokeWeight(6);
              line(endX, circleOffset, endX, increase * 2f);
              stroke(0);
              strokeWeight(1);
              line(endX, circleOffset, endX, increase * 2f);
              break;
            case 2:
              float w2 = textWidth(title);
              fill(255);
              noStroke();
              rect(endX, yOffset + increase / 2f - 1, w2, circleSize + 4);
              break;
            case 3:
              fill(0);
              noStroke();
              if(k < 0) rect(endX, circleOffset, circleSize, circleSize);
              else circle(endX, circleOffset, circleSize);
              text(title, endX, yOffset);
              break;
          }
         
          yOffset += increase;
          
        }
      }
    }
  }
  
  // Draw all the months of the year, as well as the days
  float xOffset = longestProjectNameWidth + increase + 20;
  for(int month = 0; month < 12; ++month) {
    curCal.set(Calendar.MONTH, month);
    int numDays = curCal.getActualMaximum(Calendar.DAY_OF_MONTH);
    text(monthNames[month], xOffset + numDays * increase / 2f, 0);
    for(int day = 1; day <= numDays; ++day) {
      text(day, xOffset, increase); 
      xOffset += increase;
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
