import http.requests.*;
import java.util.Date;
import java.util.Calendar;
import java.text.SimpleDateFormat;

String version = "1.1";

// Type
// 0. Calculation
// 1. Project/milestone lines
// 2. White background behind milestone names, project manager backgrounds
// 3. All text, month backgrounds
private final int LAYER_CALCULATION = 0, LAYER_LINES = 1, LAYER_BACKGROUND = 2, LAYER_TEXT = 3;

JSONLoader jsons;

float textSize = 15;
float increase = 25;
float maxHeight = 0;
float maxWidth = 0;
float longestProjectNameWidth = 0;
float projectNameIndent = 30;

String[] monthNames = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"};
String[] weekdays = {"S", "M", "T", "W", "T", "F", "S"};
SimpleDateFormat dateParser;
Calendar curCal;

boolean mouseInput = true;

int saveFrame = -1;
boolean saving = false;
boolean autoSave = false;
PImage outImage;

int translateX = 0, translateY = 0;

void setup() {
  size(1000, 500);
  //surface.setVisible(false);

  background(255);
  fill(0);
  noStroke();
  textSize(50);
  textAlign(CENTER, CENTER);
    
  rectMode(CENTER);
  
  dateParser = new SimpleDateFormat("yyyy-MM-dd");
  curCal = Calendar.getInstance();

  thread("loadJSONS");
  //jsons = new JSONLoader();
  
  //autoSave = args == null;
}

void loadJSONS() {
  jsons = new JSONLoader();
}

void draw() {
  background(255);
  
  // If we're not done loading yet, display a loading icon
  if(jsons == null || jsons.status == 0) {
    drawLoading();
    return;
  } else if(jsons.status < 0) { // If the json failed to load properly
    translate(width/2, height/2);
    textSize(50);
    fill(0);
    text("Error: is the\nAPI key set in\nconfig.json?", 0, 0);
    return;
  }
      
  if(!saving && mousePressed) {
    float mouseScale = 3f;
    translateX = (int)constrain(translateX - (mouseX - pmouseX) * mouseScale, 0, maxWidth - width + increase * 2);
    translateY = (int)constrain(translateY - (mouseY - pmouseY) * mouseScale, 0, maxHeight - height + increase * 2);
  } else if(saving) {
    int count = frameCount - saveFrame;
    int maxX = ceil(maxWidth / width);
    translateX = count % maxX * width;
    translateY = count / maxX * height;
    if(translateY >= maxHeight) saveOut();  
  }
  
  translate(-translateX + increase, -translateY + increase);
        
  float circleOffset = 0;
  float circleSize = 15;
  float lineWidth = 1.5f;
  
  float yOffset = increase * 2.5f;
  float startY = yOffset;
  maxWidth = 0;
  
  // Display the title in the upper left
  textSize(textSize * 2.5f);
  textAlign(LEFT, CENTER);
  String mainTitle = "PHA Milestones " + curCal.get(Calendar.YEAR);
  text(mainTitle, 0, textSize * 1.25f);
  longestProjectNameWidth = textWidth(mainTitle);
  textSize(textSize);

  // FOR EACH LAYER
  for(int layer = 0; layer < 4; ++layer) {
    yOffset = startY;
        
    // FOR EACH PROJECT MANAGER
    JSONArray pms = jsons.getPMs();
    for(int i = 0; i < pms.size(); ++i) {

      float startYPM = yOffset;
      
      String pmName = pms.getString(i); 
      JSONObject pm = jsons.getPM(pmName);
      JSONObject pmProjects = pm.getJSONObject("projects");
      int totalProjects = pm.getInt("numProjects");
      
      if(layer == 0 || layer == 3) {
        
        String numProjectsText = totalProjects + " active project";
        if(totalProjects > 1) numProjectsText += "s";
        
        int totalMilestones = pm.getInt("numMilestones");
        String numMilestonesText = totalMilestones + " upcoming milestone";
        if(totalMilestones > 1) numMilestonesText += "s";
        
        String pmStr = pmName + " - " + numProjectsText + ", " + numMilestonesText;
                
        float pmWidth = textWidth(pmStr) + increase;
        if(layer == LAYER_CALCULATION && pmWidth > longestProjectNameWidth) {
          longestProjectNameWidth = pmWidth - projectNameIndent;
        } else if(layer == LAYER_TEXT) {
          textAlign(LEFT, CENTER);
          fill(0);
          text(pmStr, textSize * 0.6f, yOffset + increase/2f);
        }
      }
      
      yOffset += increase; 
      
      // FOR EACH PROJECT
      for(int j = 0; j < totalProjects; ++j) {
        
        String projectID = pmProjects.getJSONArray("ids").getString(j);
        JSONArray milestones = pmProjects.getJSONArray(projectID);
        int numMilestones = milestones.size();
        
        String projectName = jsons.getProjectName(projectID);
        float projectNameWidth = textWidth(projectName);
                
        if(layer == LAYER_CALCULATION && projectNameWidth > longestProjectNameWidth)
          longestProjectNameWidth = projectNameWidth;
                
        if(layer == LAYER_TEXT) {
          textAlign(LEFT, CENTER);
          text(projectName, projectNameIndent, yOffset + increase/2f);
          textAlign(CENTER, CENTER);
        }
        
        yOffset += increase;
        circleOffset = yOffset - increase * 0.4f;
       
        float[] largestXPerMilestone = new float[numMilestones];
        int largestYOffsetIndex = 0;
        
        // FOR EACH MILESTONE
        for(int k = 0; k < numMilestones; ++k) {
          
          JSONObject milestone = jsons.getMilestone(milestones.getInt(k));
          float endX = getXFromTime(milestone.getString("deadline"));
          String title = milestone.getString("name");
          
          float w2 = textWidth(title)/2f;
          if(layer == 0) {
            if(endX + w2 > maxWidth)
              maxWidth = endX + w2 + textSize * 0.6f;
          }
          
          int yOffsetIndex = 0;
          while(largestXPerMilestone[yOffsetIndex] >= endX - w2)
            ++yOffsetIndex;
          largestXPerMilestone[yOffsetIndex] = endX + w2;
          if(yOffsetIndex > largestYOffsetIndex)
            largestYOffsetIndex = yOffsetIndex;
          float milestoneYoffset = yOffsetIndex * increase;
          
          switch(layer) {
            case 1: // Draw a vertical line up from the milestone to the calendar date
              stroke(255);
              strokeWeight(lineWidth * 4);
              line(endX, yOffset + milestoneYoffset, endX, startY);
              stroke(0);
              strokeWeight(lineWidth);
              line(endX, yOffset + milestoneYoffset, endX, startY);
              
              if(k == numMilestones - 1) {
                if(layer == LAYER_LINES) { // Draw a horizontal line from the last milestone to the very front 
                  float startX = projectNameWidth + projectNameIndent + 10;
                  float projectLineHeight = circleOffset;
                  stroke(255);
                  strokeWeight(lineWidth * 4);
                  line(startX, projectLineHeight, endX, projectLineHeight);
                  stroke(0);
                  strokeWeight(lineWidth);
                  line(startX, projectLineHeight, endX, projectLineHeight);
                }
              }
              break;
            case 2: // Draw a white background behind the milestone title
              rectMode(CENTER);
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
        } // MILESTONES
        yOffset += largestYOffsetIndex * increase + increase * 0.8f;
      } // PROJECTS
      yOffset += textSize * 0.6f;

      if(layer == 2) {
        rectMode(CORNER);
        fill(jsons.getColor(pmName));
        noStroke();
        rect(0, startYPM, maxWidth, yOffset - startYPM);
        rectMode(CENTER);
      }
    } // PROJECT MANAGERS
    
    drawMonths(layer);
    drawAbsences(layer);
  }
        
  maxHeight = yOffset;
  
    
  if(autoSave) saveOut();
  else if(saving) {
    outImage.set((int)translateX, (int)translateY, get());
  }
}

void drawLoading() {
  translate(width/2, height/2);
  textSize(50);
  fill(0);
  text("Loading...", 0, 0);
  float w = textWidth("Loading...");
  noFill();
  stroke(0);
  strokeWeight(10);
  float startAngle = frameCount / 30f + (sin(frameCount / 35f) + 1) * TWO_PI;
  float arcLength = cos(frameCount / 25f) * HALF_PI + PI * 0.6f;
  arc(0, 0, w * 1.1f, w * 1.1f, startAngle, startAngle + arcLength);
}

void drawTitle() {
  
}

// Draw all the months of the year, as well as the days
void drawMonths(int layer) {

  float backgroundHeight = (maxHeight + increase) * 2f;
  textAlign(CENTER, CENTER);
  noStroke();
  
  float xOffset = longestProjectNameWidth + projectNameIndent + increase;
  Calendar monthCal = (Calendar)curCal.clone();
  monthCal.set(Calendar.DAY_OF_MONTH, 1);
  int backgroundToggle = 0;
  
  while(monthCal.before(jsons.getLatest())) {
    
    int month = monthCal.get(Calendar.MONTH);
    int numDays = monthCal.getActualMaximum(Calendar.DAY_OF_MONTH);
    int startDay = monthCal.get(Calendar.DAY_OF_WEEK);

    switch(layer) {
      case LAYER_CALCULATION:
        xOffset += numDays * increase;
        break;
      case LAYER_BACKGROUND:
        rectMode(CORNER);
        
        if(++backgroundToggle % 2 == 1) 
          fill(jsons.getColor("monthA"));
        else 
          fill(jsons.getColor("monthB"));
        
        rect(xOffset - increase/2f, -increase, numDays * increase, backgroundHeight);
        xOffset += numDays * increase;
        break;
      case LAYER_TEXT:
        String monthText = monthNames[month];
        //monthText = (month + 1) + monthText;
        fill(0);
        text(monthText, xOffset + numDays * increase / 2f, 0); // Centered
        //text(monthText, xOffset + textWidth(monthText) / 2f, 0); // Left aligned
        
        // Days
        for(int day = 1; day <= numDays; ++day) {
          text(weekdays[(day - 2 + startDay) % weekdays.length], xOffset, increase); 
          text(day, xOffset, increase * 2f); 
          xOffset += increase;
        }
        break;
    }
    
    monthCal.add(Calendar.MONTH, 1);
  }
  
  if(xOffset > maxWidth)
    maxWidth = xOffset;

  // Draw a background rectangle on the current day
  if(layer == LAYER_BACKGROUND) {
    //blendMode(DIFFERENCE);
    rectMode(CENTER);
    fill(jsons.getColor("currentDay"), 0, 0, 50);
    noStroke();
    rect(getXFromCalendar(curCal), 0, increase, backgroundHeight);
    //blendMode(BLEND);
  }
}

void drawAbsences(int layer) {
  if(layer == LAYER_BACKGROUND) {
    pushMatrix();
    translate(-increase/2f, 0);
    JSONArray absences = jsons.getAbsences();
    rectMode(CORNERS);
    fill(jsons.getColor("absence"));
    noStroke();
    for(int i = 0; i < absences.size(); ++i) {
      JSONObject absence = absences.getJSONObject(i);
      rect(getXFromTime(absence.getString("startDate")), -increase,
           getXFromTime(absence.getString("endDate")), maxHeight + increase);
    }
    popMatrix();
  } 
}

//----------------------------------------------------//

float getXFromTime(String deadline) {
  Calendar cal = (Calendar)curCal.clone();
  try {
    cal.setTime(dateParser.parse(deadline));
    return getXFromCalendar(cal);
  } catch(Exception e) {
    e.printStackTrace(); 
  }
  return -1;
}

float getXFromCalendar(Calendar cal) {
  Calendar earliest = (Calendar)jsons.getEarliest().clone();
  earliest.set(Calendar.DAY_OF_MONTH, 1);
  return projectNameIndent + longestProjectNameWidth + increase + 
        (cal.get(Calendar.DAY_OF_YEAR) - earliest.get(Calendar.DAY_OF_YEAR)) * increase;
}

void keyPressed() {
  if(saving) return;
  
  if(key == 'q') --textSize;
  else if(key == 'a') ++textSize;
  else if(key == 'w') --increase;
  else if(key == 's') ++increase;
  else if(key == ' ') saveOut();
}

void saveOut() {
  if(saving) {
    saving = false;
  
    SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd HH-mm-ss");
    String outFilename = "PHA Milestones " + formatter.format(curCal.getTime()) + ".png";
    outFilename = outFilename.replace(" ", "_");
    outImage.save(outFilename);
    if(autoSave) exit();
  } else {
    saving = true;
    saveFrame = frameCount + 1; // Start saving next frame
    outImage = createImage((int)(maxWidth + increase * 2), (int)(maxHeight + increase * 2), RGB);
  }
}
