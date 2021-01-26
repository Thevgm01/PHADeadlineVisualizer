import http.requests.*;
import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

final boolean SEND_NEW_REQUESTS = false;

JSONLoader jsons;

float textSize = 15;
float increase = 25;
float maxHeight = 0;
float maxWidth = 0;
float longestProjectNameWidth = 0;

String[] monthNames = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"};
SimpleDateFormat creationParser, deadlineParser;
Calendar curCal, creationCal, deadlineCal;

boolean mouseInput = true;

int saving = -1;
PImage outImage;

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
  
  float translateX = 0, translateY = 0;
  if(saving < 0) {
    translateX = map(mouseX, 0, width, -increase, constrain(maxWidth - width, 0, 999999) + increase);
    translateY = map(mouseY, 0, height, -increase, constrain(maxHeight - height, 0, 999999) + increase);
  } else {
    for(int i = 0; i < saving; ++i) {
      translateX += width;
      if(translateX >= maxWidth) {
        translateX = 0;
        translateY += height;
        if(translateY >= maxHeight) {
          saveOut();
          break; 
        }
      }
    }
    translateX -= increase;
    translateY -= increase;
  }
  
  translate(-translateX, -translateY);
    
  float yOffset = 5;
  float circleOffset = 5;
  float circleSize = 10;
  
  yOffset = increase * 1.5f;
  float startY = yOffset;
  maxWidth = 0;
  //maxHeight = 0;
  
  textSize(textSize * 2);
  textAlign(LEFT, CENTER);
  String mainTitle = "PHA Milestones " + curCal.get(Calendar.YEAR);
  text(mainTitle, 0, textSize/2f);
  longestProjectNameWidth = textWidth(mainTitle);
  
  textSize(textSize);

  // FOR EACH TYPE
  for(int type = 0; type < 4; ++type) {
    yOffset = startY;
    
    if(type == 3) {
      float borderHeight = (maxHeight + increase) * 2f;
      noStroke();
      
      // Draw all the months of the year, as well as the days
      float xOffset = longestProjectNameWidth + increase + 20;
      for(int month = 0; month < 12; ++month) {
        deadlineCal.set(Calendar.MONTH, month);
        int numDays = deadlineCal.getActualMaximum(Calendar.DAY_OF_MONTH);

        // Background
        if(month % 2 == 0) fill(80, 100, 255, 50);
        else fill(40, 100, 255, 50);
        rect(xOffset + (numDays - 1) * increase/2f, 0, numDays * increase, borderHeight);    
        
        String monthText = (month + 1) + " - " + monthNames[month];
        // Month name
        fill(0);
        text(monthText, xOffset + numDays * increase / 2f, 0); // Centered
        //text(monthText, xOffset + textWidth(monthText) / 2f, 0); // Left aligned
        
        // Days
        for(int day = 1; day <= numDays; ++day) {
          text(day, xOffset, increase); 
          xOffset += increase;
        }
      }
  
      // Draw a background rectangle on the current day
      fill(0, 100, 255, 50);
      noStroke();
      rect(longestProjectNameWidth + 20 + curCal.get(Calendar.DAY_OF_YEAR) * increase, 0, increase, borderHeight);
    }
    
    // FOR EACH PROJECT MANAGER
    JSONArray pms = jsons.getPMs();
    for(int i = 0; i < pms.size(); ++i) {
      //fill(color(mainHue, 255, 100));
      //mainHue += 50;
      
      String pm = pms.getString(i); 
      JSONArray projects = jsons.getProjects(pm);
      
      if(type == 0) {
        String numProjects = projects.size() + " active project";
        if(projects.size() > 1) numProjects += "s";
        
        textAlign(LEFT, CENTER);
        fill(0);
        text(pm + " - " + numProjects, 0, yOffset + increase/2f);
      }
      
      yOffset += increase; 
      
      // FOR EACH PROJECT
      for(int j = 0; j < projects.size(); ++j) {
        String projectID = projects.getString(j);
        JSONArray milestones = jsons.getMilestones(pm, projectID);
             
        String projectName = milestones.getJSONObject(0).getString("project-name");
        float projectNameWidth = textWidth(projectName);
                
        if(type == 0) {
          textAlign(LEFT, CENTER);
          if(projectNameWidth > longestProjectNameWidth)
            longestProjectNameWidth = projectNameWidth;
          text(projectName, 20, yOffset + increase/2f);
          textAlign(CENTER, CENTER);
        }
        
        yOffset += increase;
        circleOffset = yOffset - increase * 0.4f;

        if(type == 1) { // Draw a horizontal line from the last milestone to the very front 
          setCalendar(deadlineCal, milestones.getJSONObject(milestones.size() - 1));
          
          float startX = projectNameWidth + 30;
          float endX = longestProjectNameWidth + 20 + deadlineCal.get(Calendar.DAY_OF_YEAR) * increase;
          if(deadlineCal.get(Calendar.YEAR) > curCal.get(Calendar.YEAR))
            endX = curCal.getActualMaximum(Calendar.DAY_OF_YEAR) * increase; 
          
          stroke(0);
          strokeWeight(1);
          line(startX, circleOffset, endX, circleOffset);
        }
        
        // FOR EACH MILESTONE
        for(int k = -1; k < milestones.size(); ++k) {
          
          float endX;
          String title;
          if(k < 0) { // Creation date
            setCalendar(creationCal, milestones.getJSONObject(0));
            if(creationCal.get(Calendar.YEAR) < curCal.get(Calendar.YEAR))
              endX = longestProjectNameWidth + 20 + increase;
            else
              endX = longestProjectNameWidth + 20 + creationCal.get(Calendar.DAY_OF_YEAR) * increase;
            title = "Created on " + milestones.getJSONObject(0).getString("created-on");
            title = title.substring(0, title.indexOf("T"));
          } else { // Deadline date
            JSONObject milestone = milestones.getJSONObject(k);
            setCalendar(deadlineCal, milestone);
            endX = longestProjectNameWidth + 20 + deadlineCal.get(Calendar.DAY_OF_YEAR) * increase;
            title = milestone.getString("title");
          }
          
          float w2 = textWidth(title);
          if(type == 0) 
            if(endX + w2/2f > maxWidth)
              maxWidth = endX + w2/2f;
                    
          switch(type) {
            case 1: // Draw a vertical line up from the milestone to the calendar date
              stroke(255);
              strokeWeight(5f);
              line(endX, yOffset + increase/2f, endX, increase + textSize);
              stroke(0);
              strokeWeight(1);
              line(endX, yOffset + increase/2f, endX, increase + textSize);
              break;
            case 2: // Draw a white background behind the milestone title
              fill(255);
              noStroke();
              rect(endX, yOffset + increase * 0.6f, w2, textSize + 5f);
              break;
            case 3: // Draw the milestone title and circle
              fill(0);
              noStroke();
              if(k < 0) rect(endX, circleOffset, circleSize, circleSize);
              else circle(endX, circleOffset, circleSize);
              text(title, endX, yOffset + increase/2f);
              break;
          }
         
          yOffset += increase;
        }
        yOffset += increase * 0.25f;
      }
      if(i < pms.size() - 1) {
        switch(type) {
          case 2:
            stroke(255);
            strokeWeight(8);
            line(-maxWidth, yOffset, maxWidth * 2, yOffset);
            break;
          case 3:
            stroke(0);
            strokeWeight(3);
            line(-maxWidth, yOffset, maxWidth * 2, yOffset);
            break;
        }
      }
    }
  }
        
  maxHeight = yOffset;
  
  if(saving >= 0) {
    outImage.set((int)(translateX + increase), (int)(translateY + increase), get());
    ++saving;
  }
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

void keyPressed() {
  if(key == 'q') --textSize;
  else if(key == 'a') ++textSize;
  else if(key == 'w') --increase;
  else if(key == 's') ++increase;
  else if(key == ' ' && saving < 0) saveOut();
}

void saveOut() {
  if(saving >= 0) {
    saving = -1; 
  
    SimpleDateFormat formatter = new SimpleDateFormat("dd-MM-yyyy HH-mm-ss");
    String outFilename = "PHA Milestones " + formatter.format(new Date()) + ".png";
    outFilename = outFilename.replace(" ", "_");
    outImage.save(outFilename);
  } else {
    saving = 0;
    outImage = createImage((int)(maxWidth + increase * 2), (int)(maxHeight + increase * 2), RGB);
  }
}
