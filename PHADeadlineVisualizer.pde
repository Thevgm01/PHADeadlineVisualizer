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
SimpleDateFormat dateParser;
Calendar curCal, creationCal, deadlineCal, earliestCal, latestCal;

boolean mouseInput = true;

int saving = -1;
PImage outImage;

void setup() {
  size(1000, 500);
  //frame.setVisible(false);
  background(255);
  noStroke();
    
  rectMode(CENTER);
  
  dateParser = new SimpleDateFormat("yyyy-MM-dd");
  curCal = Calendar.getInstance();
  creationCal = Calendar.getInstance();
  deadlineCal = Calendar.getInstance();
  earliestCal = Calendar.getInstance();
  latestCal = Calendar.getInstance();
  
  jsons = new JSONLoader(false);
}

// Type
// 0. Calculation
// 1. Project/milestone lines
// 2. White background behind milestone names, project manager backgrounds
// 3. All text, month backgrounds

void draw() {
  background(255);
  
  float translateX = 0, translateY = 0;
  if(saving < 0) {
    translateX = map(mouseX, 0, width, 0, constrain(maxWidth - width, 0, 999999) + increase*2);
    translateY = map(mouseY, 0, height, 0, constrain(maxHeight - height, 0, 999999) + increase*2);
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
  }
  
  translate(-translateX + increase, -translateY + increase);
    
  float projectNameIndent = 20;
    
  float circleOffset = 0;
  float circleSize = 15;
  float lineWidth = 1.5f;
  
  float yOffset = increase * 1.5f;
  float startY = yOffset;
  maxWidth = 0;
  
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
      textAlign(CENTER, CENTER);
      noStroke();
      
      // Draw all the months of the year, as well as the days
      float xOffset = longestProjectNameWidth + projectNameIndent + increase;
      Calendar cal = (Calendar)earliestCal.clone();
      while(!cal.after(latestCal)) {
        int month = cal.get(Calendar.MONTH);
        int numDays = cal.getActualMaximum(Calendar.DAY_OF_MONTH);

        // Background
        if(month % 2 == 0) {
          fill(0, 15);
          rect(xOffset + (numDays - 1) * increase/2f, 0, numDays * increase, borderHeight);
        }
        
        String monthText = (month + 1) + " - " + monthNames[month];
        // Month name
        fill(0);
        //text(monthText, xOffset + numDays * increase / 2f, 0); // Centered
        text(monthText, xOffset + textWidth(monthText) / 2f, 0); // Left aligned
        
        // Days
        for(int day = 1; day <= numDays; ++day) {
          text(day, xOffset, increase); 
          xOffset += increase;
        }
        
        cal.add(Calendar.MONTH, 1);
      }
      
      if(xOffset > maxWidth)
        maxWidth = xOffset + textSize * 0.6f;
  
      // Draw a background rectangle on the current day
      //blendMode(DIFFERENCE);
      fill(255, 0, 0, 50);
      noStroke();
      rect(longestProjectNameWidth + projectNameIndent + curCal.get(Calendar.DAY_OF_YEAR) * increase, 0, increase, borderHeight);
      //blendMode(BLEND);
    }
    
    // FOR EACH PROJECT MANAGER
    JSONArray pms = jsons.getPMs();
    for(int i = 0; i < pms.size(); ++i) {

      float startYPM = yOffset;
      
      String pm = pms.getString(i); 
      JSONArray projects = jsons.getProjects(pm);
      
      if(type == 3) {
        String numProjects = projects.size() + " active project";
        if(projects.size() > 1) numProjects += "s";
        
        textAlign(LEFT, CENTER);
        fill(0);
        text(pm + " - " + numProjects, textSize * 0.6f, yOffset + increase/2f);
      }
      
      yOffset += increase; 
      
      // FOR EACH PROJECT
      for(int j = 0; j < projects.size(); ++j) {
        String projectID = projects.getString(j);
        JSONArray milestones = jsons.getMilestones(pm, projectID);
        
        String projectName = jsons.getProjectName(projectID);
        float projectNameWidth = textWidth(projectName);
                
        if(type == 0 && projectNameWidth > longestProjectNameWidth)
          longestProjectNameWidth = projectNameWidth;
                
        if(type == 3) {
          textAlign(LEFT, CENTER);
          text(projectName, projectNameIndent, yOffset + increase/2f);
          textAlign(CENTER, CENTER);
        }
        
        yOffset += increase;
        circleOffset = yOffset - increase * 0.4f;

        if(type == 1) { // Draw a horizontal line from the last milestone to the very front 
          setDeadline(jsons.getMilestone(milestones.getString(milestones.size() - 1)));
          
          float startX = projectNameWidth + projectNameIndent + 10;
          float endX = longestProjectNameWidth + projectNameIndent + deadlineCal.get(Calendar.DAY_OF_YEAR) * increase;
          
          stroke(0);
          strokeWeight(lineWidth);
          line(startX, circleOffset, endX, circleOffset);
        }
        
        float[] largestXPerMilestone = new float[milestones.size()];
        int largestYOffsetIndex = 0;
        
        // FOR EACH MILESTONE
        for(int k = 0; k < milestones.size(); ++k) {
          
          JSONObject milestone = jsons.getMilestone(milestones.getString(k));
          setDeadline(milestone);
          float endX = longestProjectNameWidth + projectNameIndent + deadlineCal.get(Calendar.DAY_OF_YEAR) * increase;
          String title = milestone.getString("name");
          
          if(deadlineCal.after(latestCal)) {
            latestCal = (Calendar)deadlineCal.clone();
          }
          
          float w2 = textWidth(title)/2f;
          if(type == 0) 
            if(endX + w2 > maxWidth)
              maxWidth = endX + w2 + textSize * 0.6f;
          
          int yOffsetIndex = 0;
          while(largestXPerMilestone[yOffsetIndex] >= endX - w2)
            ++yOffsetIndex;
          largestXPerMilestone[yOffsetIndex] = endX + w2;
          if(yOffsetIndex > largestYOffsetIndex)
            largestYOffsetIndex = yOffsetIndex;
          float milestoneYoffset = yOffsetIndex * increase;
          
          switch(type) {
            case 1: // Draw a vertical line up from the milestone to the calendar date
              stroke(255);
              strokeWeight(lineWidth * 4);
              line(endX, yOffset + milestoneYoffset, endX, increase + textSize);
              stroke(0);
              strokeWeight(lineWidth);
              line(endX, yOffset + milestoneYoffset, endX, increase + textSize);
              break;
            case 2: // Draw a white background behind the milestone title
              fill(255);
              noStroke();
              rect(endX, yOffset + milestoneYoffset + increase * 0.5f, w2*2f, textSize + 5f);
              break;
            case 3: // Draw the milestone title and circle
              fill(0);
              noStroke();
              circle(endX, circleOffset, circleSize);
              text(title, endX, yOffset + milestoneYoffset + increase * 0.4f);
              break;
          }
        }
        yOffset += largestYOffsetIndex * increase + increase * 0.8f;
      }
      yOffset += textSize * 0.6f;
      /*if(i < pms.size() - 1) {
        switch(type) {
          case 2:
            stroke(255);
            strokeWeight(lineWidth * 6);
            line(-maxWidth, yOffset, maxWidth * 2, yOffset);
            break;
          case 3:
            stroke(0);
            strokeWeight(lineWidth * 3);
            line(-maxWidth, yOffset, maxWidth * 2, yOffset);
            break;
        }
      }*/
      if(type == 2) {
        rectMode(CORNER);
        String hex = jsons.getPMHex(pm);
        fill(unhex(hex), 20);
        noStroke();
        rect(0, startYPM, maxWidth, yOffset - startYPM);
        rectMode(CENTER);
      }
    }
  }
        
  maxHeight = yOffset;
  
  if(saving >= 0) {
    outImage.set((int)translateX, (int)translateY, get());
    ++saving;
  }
}

void setDeadline(JSONObject milestone) {
  try {
    String date = milestone.getString("deadline");
    deadlineCal.setTime(dateParser.parse(date));
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
