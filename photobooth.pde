import java.awt.*;
import processing.video.*;
import java.util.Comparator;
import java.util.Arrays;
import java.io.File;

boolean debug = true;
boolean showVideo = false;
boolean fullscreenEnabled = true;

Capture video;
PImage videoResized;
Rectangle[] faces;

final int APPROVE_DELAY = 5 *1000; // delay before the picture is saved
final int SHOW_MORPH_DELAY = 2 *1000; // how long to display the final saved morph
final int FLASH_DELAY = 200; // how long to flash a white background
final int NR_OF_PHOTOS = 3; // how many pictures to take

color backgroundColor = color(214,210,207);
color marginColor = color(214,210,207);
color progressFillColor = color(214,210,207);
color progressStrokeColor = color(125);
color textColor = color(80);
color flashColor = color(255);


final int MODE_IDLE = 0;
final int MODE_COUNTDOWN = 1;
final int MODE_SAVING_PHOTO = 2;
final int MODE_DISPLAY_PHOTO = 3; //display the saved picture for a while
int mode = MODE_IDLE;
int nrOfPhotosTaken = 0;
int startTime;

// parameters for the location of the morphed face
int screenWidth, screenHeight, marginH, marginV, videoScaledWidth, videoScaledHeight;
int progressCircleWidth, progessCircleHeight, progressCircleX, progressCircleY, galleryX, galleryY, frameWidth, frameHeight;



// just some supported resolutions for the logitech webcam c930e:
// 640x360
// 800x600
// 960x540
// 1024x576
// 1280x720
// 1600x896
// 1920x1080
// 2304x1536 (max res)
final int VIDEO_RES_WIDTH = 1280; // max = 2304x1536 (logitech 1080p)
final int VIDEO_RES_HEIGHT = 720;

int overlayWidth = VIDEO_RES_WIDTH;
int overlayHeight = VIDEO_RES_HEIGHT;


float scale = 1.0;

//float openCVScale = 0.2;

String[] overlayFiles;

PImage imgOverlay;



String lastMorphNr = "";
String photosDir, photosOriginalDir;
String[] photosFiles;
int prevNrFiles = 0;
Comparator<File> byModificationDate = new ModificationDateCompare();
int galleryCounter = 0;
PImage[] galleryImgs;
int galleryMode = 11;
boolean newMorphAvailable = false;

void settings() {
  //size(320, 240, P3D);
  //size(1366, 768);
  fullScreen(1);
  //smooth();
}

void setup() {
  //size(1366, 768);
  //fullScreen(1); // needs to be on first line. Can add argument for which screen. 
  
  screenWidth = width; //1366;
  screenHeight = height; //768;
  marginH = 54;
  marginV = 54;

  progressCircleWidth = 200;
  progessCircleHeight = 200;
  progressCircleX = screenWidth/2; //screenWidth - marginH - progressCircleWidth +50;
  progressCircleY = screenHeight/2;
  galleryX = marginH;
  galleryY = marginV;
  frameWidth = screenWidth - (marginH * 2);
  frameHeight = screenHeight - (marginV * 2);

  println("screenWidth: "+screenWidth);
  println("screenHeight: "+screenHeight);
  scale = min( (screenWidth - 2.0*marginH) / (VIDEO_RES_WIDTH*1.0), (screenHeight - 2.0*marginV) / (VIDEO_RES_HEIGHT*1.0));
  videoScaledWidth = int(VIDEO_RES_WIDTH * scale);
  videoScaledHeight = int(VIDEO_RES_HEIGHT * scale);
  //scale = (screenWidth - 2.0*marginH) / (VIDEO_RES_WIDTH*1.0);
  println("scale: "+scale);
  println("scaled video width plus margins: " + (videoScaledWidth + 2*marginH));
  println("scaled video height plus margins: "+ (videoScaledHeight + 2*marginV));
  //frame.setResizable(true);
  
  
  String[] cameras = Capture.list();
  println("Found "+cameras.length+" webcams!");
  int selectedCameraIndex = 0;
  for(int i = 0; i < cameras.length; i++)
  {
    //println(i+ ": "+cameras[i]);
    if(trim(cameras[i]).equals("name=HD Pro Webcam C920,size=1280x720,fps=30")) {
      selectedCameraIndex = i;
      println("Selected camera index "+selectedCameraIndex);
    }
  }
  
  video = new Capture(this, VIDEO_RES_WIDTH, VIDEO_RES_HEIGHT, Capture.list()[selectedCameraIndex]); //
  
  startTime = millis();
  mode = 0;
  
  //textFont(createFont("Whitney", 36));
  textFont(createFont("olivier Regular", 36));
  
  overlayFiles = listFileNames(sketchPath()+"/img/overlay");
  
  
  
  photosDir = sketchPath()+"/photos/withoverlay";
  photosOriginalDir = sketchPath()+"/photos/plain";
  //lastMorphNr = listFileNames(photosDir).length-1;
  if(debug) println("lastMorphNr="+lastMorphNr);
  
  galleryImgs = new PImage[galleryMode];
  
  video.start();
  
  //String[] args = {"YourSketchNameHere"};
  //GalleryApplet sa = new GalleryApplet();
  //PApplet.runSketch(args, sa);
}


void draw() {
  background(backgroundColor);
  
  // draw margins for debug
  fill(marginColor);
  noStroke();
  rect(0, 0, screenWidth, marginV);
  rect(0, screenHeight-marginV, screenWidth, marginV);
  rect(0, 0, marginH, screenHeight);
  rect(screenWidth-marginH, 0, marginH, screenHeight);
  //rect(screenWidth/2.0-marginH, 0, marginH*2.0, screenHeight);
  
  
  //*********
  // gallery
  
  //displayGallery();
  
  //***************
  
  
  //PImage videoResized = new PImage(video.width, video.height);
  video.loadPixels();
  /*videoResized.loadPixels();
  videoResized.pixels = video.pixels;
  videoResized.updatePixels();
  videoResized.resize(opencv.width, opencv.height);
  opencv.loadImage(videoResized);
  */
  
  
  
  // show the camera image
  if(showVideo) image(video,0,0, video.width, video.height);


  switch(mode)
  {
    case MODE_IDLE:  // waiting
      displayGallery();
      break;
    case MODE_COUNTDOWN :  // wait untill start delay has passed
      if (millis() - startTime > APPROVE_DELAY)
      {
        mode = MODE_SAVING_PHOTO;
        println("Switching to SAVING");
        if(debug) println("mode="+mode);
        startTime = millis();
      }
      else
      {
        //fill(255);
        //rect(marginH,marginV, 1366, 768);
        //println(VIDEO_RES_WIDTH * scale);
        image(video,marginH + (frameWidth - videoScaledWidth)/2.0, marginV + (frameHeight - videoScaledHeight)/2.0, videoScaledWidth, videoScaledHeight);
        image(imgOverlay, marginH + (frameWidth - videoScaledWidth)/2.0, marginV + (frameHeight - videoScaledHeight)/2.0, videoScaledWidth, videoScaledHeight);
        
        int seconds = round((APPROVE_DELAY - (millis() - startTime))/1000);
        //fill(0);
        //textSize(18);
        //text("Sparar bilden om " + seconds + " sekunder.", 10, 30);
        //noFill();
        fill(progressFillColor);
        stroke(progressStrokeColor);
        strokeWeight(20);
        arc(progressCircleX, progressCircleY, progressCircleWidth, progessCircleHeight, PI/-2.0, PI/-2.0 + 2*PI*((millis() - startTime)/(APPROVE_DELAY*1.0)));
        fill(textColor);
        textSize(80);
        text(seconds, progressCircleX-10, progressCircleY+20);
      }
      break;
    case MODE_SAVING_PHOTO:  // display the generated morph
      if(debug) println("Saving picture");
      
      // append a 0 if the value is only one character
      String hours = (hour()<10) ? "00" : ""+hour();
      String minutes = (minute()<10) ? "00" : ""+minute();
      String seconds = (second()<10) ? "00" : ""+second();
      lastMorphNr = ""+year() + month() + day() + hours + minutes + seconds;
      println("lastMorphNr="+lastMorphNr);
      
      PGraphics saveMorph = createGraphics(VIDEO_RES_WIDTH, VIDEO_RES_HEIGHT); // create an image to save the morph as a file with transparency
      saveMorph.beginDraw();
      
      saveMorph.image(video,0,0, video.width, video.height);
      saveMorph.save(photosOriginalDir+"/photobooth"+lastMorphNr+".png");
      
      saveMorph.image(imgOverlay, 0, 0, overlayWidth, overlayHeight);
      
      saveMorph.endDraw();
      
      
      
      // save the picture as a file
      
      //saveFrame(photosDir+"/photobooth"+lastMorphNr+".png");
      saveMorph.save(photosDir+"/photobooth"+lastMorphNr+".png");
      
      newMorphAvailable = true;
      nrOfPhotosTaken++;
      
      //deleteOldestFiles();
      
      mode = MODE_DISPLAY_PHOTO;
      println("Switching to DISPLAY");
      startTime = millis();
      
      break;
    case MODE_DISPLAY_PHOTO: // display the saved image for a while and go back to idle mode
      //background(0);
      if(millis() - startTime < SHOW_MORPH_DELAY + FLASH_DELAY)
      {
        PImage morph = loadImage(photosDir+"/photobooth"+lastMorphNr+".png");

        if(millis() - startTime < FLASH_DELAY)
        {
          println("Flash!");
          fill(flashColor);
          rect(marginH, marginV, frameWidth, frameHeight);
        }
        else
        {
          //println("Showing..");
          image(morph,marginH + (frameWidth - videoScaledWidth)/2.0, marginV + (frameHeight - videoScaledHeight)/2.0, videoScaledWidth, videoScaledHeight);
        }
      }
      else
      {
        if(nrOfPhotosTaken < NR_OF_PHOTOS)
        {
           mode = MODE_COUNTDOWN;
           startTime = millis();
           println("Switching to COUNTDOWN");
        }
        else
        {
          mode = MODE_IDLE;
          println("Switching to IDLE");
        }
      }
      break;
  }

  if(debug)
  {
    //println("framerate:"+frameRate);
    fill(0);
    textSize(20);
    text(frameRate, 10, 30);
  }
  //println("framerate:"+frameRate);
}

PImage cutOutRectangle(PImage source, Rectangle rect, float scale)
{
  PGraphics pic = createGraphics(int(rect.width/scale),int(rect.height/scale));
  pic.beginDraw();
  pic.image(source, -rect.x/scale, -rect.y/scale);
  pic.endDraw();
  return pic.get();
}

void startOver() {  
    mode = 0;
    if(debug) println("mode="+mode);
}


void rectangleAround(Rectangle[] objects, int threshold)
{
  noFill();
  stroke(255, 0, 0);
  strokeWeight(3);
  for (int i = 0; i < objects.length; i++) {
    stroke(255, 0, 0);
    if(objects[i].y > threshold)
      stroke(0, 0, 255);
    rect(objects[i].x, objects[i].y, objects[i].width, objects[i].height);
  }
}

void captureEvent(Capture c) {
  c.read();
}

void pause()
{
  try {
      Thread.sleep(1000);                 //1000 milliseconds is one second.
  } catch(InterruptedException ex) {
      Thread.currentThread().interrupt();
  } 
}


String[] listFileNames(String dir) {
  //if(debug) println("reading filenames in dir " + dir);
  File file = new File(dir);
  if (file.isDirectory()) {
    File[] files = file.listFiles();
    Arrays.sort(files, byModificationDate);
    String[] names = new String[files.length];
    int j = 0;
    for(int i = 0; i < files.length;i++)
    {
      // skip directories and mac hidden files
      if(files[i].isDirectory() == false && files[i].getName().substring(0,1).equals(".") == false)
      {
        names[j] = files[i].getName();
        j++;
      }
    }
    
    String[] names2 = new String[j];
    for(int i = 0; i < names2.length;i++)
    {
      names2[i] = names[i];
    }
    
    //if(debug) println("found "+names.length+" files");
    return names2;
  } else {
    // If it's not a directory
    println("Warning: this is not a directory:"+dir);
    return null;
  }
}

class ModificationDateCompare implements Comparator<File> {
  public int compare(File f1, File f2) {
    return Long.valueOf(f1.lastModified()).compareTo(f2.lastModified());    
  }
}

PImage loadRandom(String dir, String[] files)
{
  return loadImage("img/"+dir+"/"+files[int(random(files.length))]);
}


void displayGallery()
{
  if(photosFiles == null || newMorphAvailable)
    photosFiles = listFileNames(photosDir);

  if(photosFiles == null ||photosFiles.length <= 0)
  {
    fill(0);
    println("Error: no images found in dir "+photosDir+" to display in the gallery.");
    return;
  }
  
  if(galleryImgs[galleryImgs.length-1] == null)
  {
    // load new images
    if(photosFiles.length < galleryImgs.length)
    {
      println("Warning: There are less images available("+photosFiles.length+") that what will be displayed in the gallery("+galleryImgs.length+"), so you will see some more than once.");
    }
    for(int i = 0; i<galleryImgs.length;i++)
    {
      galleryImgs[i] = loadImage(photosDir + "/" + photosFiles[int(random(photosFiles.length))]);
    }
  }
  
  if(galleryCounter%100 == 0 || newMorphAvailable)
  {
    // move all images one step in the array
    
    
    if(newMorphAvailable)
    {
      // new pictures have been taken. Make space by moving all previous images enough steps
      for(int i = galleryImgs.length-1; i > NR_OF_PHOTOS-1; i--)
      {
        galleryImgs[i] = galleryImgs[i-NR_OF_PHOTOS];
      }
      
      for(int i = 0; i < NR_OF_PHOTOS; i++) 
      {
        galleryImgs[i] = loadImage(photosDir + "/" + photosFiles[photosFiles.length-(i+1)]);
      }
    }
    else
    {
      // just add one random image and move all others one step
      for(int i = galleryImgs.length-1; i > 0; i--)
      {
        galleryImgs[i] = galleryImgs[i-1];
      }
      // new image on index 0
      galleryImgs[0] = loadImage(photosDir + "/" + photosFiles[int(random(photosFiles.length))]);
    }
    
    // reset to start over
    newMorphAvailable = false;
    galleryCounter = 0;
  }
  
  int imgIndex = 0;
  switch(galleryMode)
  {
    case 1:
      image(galleryImgs[0], galleryX, galleryY, frameWidth, frameHeight);
      break;
    case 4:
    case 16:
    case 25:
      
      float sqroot = sqrt(galleryMode);
      for(int i = 0; i<sqroot;i++)
      {
        for(int j = 0; j<sqroot;j++)
        {
          image(galleryImgs[imgIndex], galleryX+j*frameWidth/sqroot, galleryY+i*frameHeight/sqroot, frameWidth/sqroot, frameHeight/sqroot);
          imgIndex++;
        }
      }
      break;
    case 10:
      image(galleryImgs[imgIndex], galleryX, galleryY, frameWidth/2, frameHeight/2);
      imgIndex++;
      for(int i = 0; i<2;i++)
      {
        for(int j = 0; j<2;j++)
        {
          image(galleryImgs[imgIndex], galleryX+frameWidth/2+j*frameWidth/4, galleryY+i*frameHeight/4, frameWidth/4, frameHeight/4);
          imgIndex++;
        }
      }
      
      for(int i = 0; i<2;i++)
      {
        for(int j = 0; j<2;j++)
        {
          image(galleryImgs[imgIndex], galleryX+j*frameWidth/4, galleryY+frameHeight/2+i*frameHeight/4, frameWidth/4, frameHeight/4);
          imgIndex++;
        }
      }
      image(galleryImgs[imgIndex], galleryX+frameWidth/2, galleryY+frameHeight/2, frameWidth/2, frameHeight/2);
      imgIndex++;
      
      fill(255);
      textSize(50);
      text("Press the button to take a picture!", marginH+200, screenHeight/2+50);
      break;
    case 11:
      //top left 2 small
      image(galleryImgs[imgIndex], galleryX, galleryY, frameWidth/4, frameHeight/4);
      imgIndex++;
      image(galleryImgs[imgIndex], galleryX+frameWidth/4, galleryY, frameWidth/4, frameHeight/4);
      imgIndex++;
      // top right one big
      image(galleryImgs[imgIndex], galleryX+frameWidth/2, galleryY, frameWidth/2, frameHeight/2);
      imgIndex++;
      // top left 2 small
      image(galleryImgs[imgIndex], galleryX, galleryY+frameHeight/4, frameWidth/4, frameHeight/4);
      imgIndex++;
      image(galleryImgs[imgIndex], galleryX+frameWidth/4, galleryY+frameHeight/4, frameWidth/4, frameHeight/4);
      imgIndex++;
      
      
      // 2nd half
      // bottom left 3 small
      image(galleryImgs[imgIndex], galleryX, galleryY+frameHeight/2, frameWidth/4, frameHeight/4);
      imgIndex++;
      image(galleryImgs[imgIndex], galleryX, galleryY+frameHeight/2+frameHeight/4, frameWidth/4, frameHeight/4);
      imgIndex++;
      image(galleryImgs[imgIndex], galleryX+frameWidth/4, galleryY+frameHeight/2+frameHeight/4, frameWidth/4, frameHeight/4);
      imgIndex++;
          
      // bottom right 3 small 
      image(galleryImgs[imgIndex], galleryX+frameWidth/2+frameWidth/4, galleryY+frameHeight/2, frameWidth/4, frameHeight/4);
      imgIndex++;
      image(galleryImgs[imgIndex], galleryX+frameWidth/2, galleryY+frameHeight/2+frameHeight/4, frameWidth/4, frameHeight/4);
      imgIndex++;
      image(galleryImgs[imgIndex], galleryX+frameWidth/2+frameWidth/4, galleryY+frameHeight/2+frameHeight/4, frameWidth/4, frameHeight/4);
      imgIndex++;
      
      fill(75);
      textSize(65);
      text("Press the button to take a picture!", galleryX+frameWidth/4+40, galleryY+frameHeight/2+frameHeight/8+20);
      break;
  }
  
  prevNrFiles = photosFiles.length;
  galleryCounter++;
}

int resizeWidth(int originalWidth, int originalHeight, int newHeight)
{
  return int((newHeight/(1.0*originalHeight))*originalWidth);
}

int resizeHeight(int originalWidth, int originalHeight, int newWidth)
{
  return int((newWidth/(1.0*originalWidth))*originalHeight);
}

void deleteOldestFiles()
{
  photosFiles = listFileNames(photosDir);
  while(photosFiles.length > 30)
  {
    boolean success = false; 
    try{
      success = (new File(photosDir +"/"+  photosFiles[0])).delete();
    }
    catch(NullPointerException e)
    {
      println("NullPointerException: Could not find the file that I wanted to delete.");
    }
    if(debug) println("Tried to remove file "+photosDir+" "+photosFiles[0]+ " and success="+success);
    if(!success)
    {
      println("Warning! Could not remove file: "+photosDir+"/"+photosFiles[0]+" So I'll stop trying now. This means you might end up with a lot of files after a long time.");
    }
    photosFiles = listFileNames(photosDir);
  }
}

void keyPressed() {
  if(debug) println("pressed:"+key);
  
  if(key == 'c')
  {
    startCountdown();
  }
}

void startCountdown() {
  startTime = millis();
  mode = 1;
  imgOverlay = loadRandom("overlay", overlayFiles);
  if(debug) println("mode="+mode);
}





public class GalleryApplet extends PApplet {
 
  public void settings() {
    //size(200, 100);
    fullScreen(3);
  }
  public void draw() {
    background(255);
    fill(0);
    ellipse(100, 50, 10, 10);
  }
}





/*
Found 147 webcams.
0: name=USB 2.0 Webcam Device,size=640x480,fps=5
1: name=USB 2.0 Webcam Device,size=640x480,fps=30
2: name=USB 2.0 Webcam Device,size=160x120,fps=5
3: name=USB 2.0 Webcam Device,size=160x120,fps=30
4: name=USB 2.0 Webcam Device,size=176x144,fps=5
5: name=USB 2.0 Webcam Device,size=176x144,fps=30
6: name=USB 2.0 Webcam Device,size=320x180,fps=5
7: name=USB 2.0 Webcam Device,size=320x180,fps=30
8: name=USB 2.0 Webcam Device,size=320x240,fps=5
9: name=USB 2.0 Webcam Device,size=320x240,fps=30
10: name=USB 2.0 Webcam Device,size=352x288,fps=5
11: name=USB 2.0 Webcam Device,size=352x288,fps=30
12: name=USB 2.0 Webcam Device,size=424x240,fps=5
13: name=USB 2.0 Webcam Device,size=424x240,fps=30
14: name=USB 2.0 Webcam Device,size=640x360,fps=5
15: name=USB 2.0 Webcam Device,size=640x360,fps=30
16: name=USB 2.0 Webcam Device,size=848x480,fps=5
17: name=USB 2.0 Webcam Device,size=848x480,fps=10
18: name=USB 2.0 Webcam Device,size=960x540,fps=5
19: name=USB 2.0 Webcam Device,size=960x540,fps=10
20: name=USB 2.0 Webcam Device,size=1280x720,fps=5
21: name=USB 2.0 Webcam Device,size=1280x720,fps=10
22: name=USB 2.0 Webcam Device,size=640x480,fps=5
23: name=USB 2.0 Webcam Device,size=640x480,fps=30
24: name=USB 2.0 Webcam Device,size=160x120,fps=5
25: name=USB 2.0 Webcam Device,size=160x120,fps=30
26: name=USB 2.0 Webcam Device,size=176x144,fps=5
27: name=USB 2.0 Webcam Device,size=176x144,fps=30
28: name=USB 2.0 Webcam Device,size=320x180,fps=5
29: name=USB 2.0 Webcam Device,size=320x180,fps=30
30: name=USB 2.0 Webcam Device,size=320x240,fps=5
31: name=USB 2.0 Webcam Device,size=320x240,fps=30
32: name=USB 2.0 Webcam Device,size=352x288,fps=5
33: name=USB 2.0 Webcam Device,size=352x288,fps=30
34: name=USB 2.0 Webcam Device,size=424x240,fps=5
35: name=USB 2.0 Webcam Device,size=424x240,fps=30
36: name=USB 2.0 Webcam Device,size=640x360,fps=5
37: name=USB 2.0 Webcam Device,size=640x360,fps=30
38: name=USB 2.0 Webcam Device,size=848x480,fps=5
39: name=USB 2.0 Webcam Device,size=848x480,fps=30
40: name=USB 2.0 Webcam Device,size=960x540,fps=5
41: name=USB 2.0 Webcam Device,size=960x540,fps=30
42: name=USB 2.0 Webcam Device,size=1280x720,fps=5
43: name=USB 2.0 Webcam Device,size=1280x720,fps=30
44: name=HD Pro Webcam C920,size=640x480,fps=5
45: name=HD Pro Webcam C920,size=640x480,fps=30
46: name=HD Pro Webcam C920,size=160x90,fps=5
47: name=HD Pro Webcam C920,size=160x90,fps=30
48: name=HD Pro Webcam C920,size=160x120,fps=5
49: name=HD Pro Webcam C920,size=160x120,fps=30
50: name=HD Pro Webcam C920,size=176x144,fps=5
51: name=HD Pro Webcam C920,size=176x144,fps=30
52: name=HD Pro Webcam C920,size=320x180,fps=5
53: name=HD Pro Webcam C920,size=320x180,fps=30
54: name=HD Pro Webcam C920,size=320x240,fps=5
55: name=HD Pro Webcam C920,size=320x240,fps=30
56: name=HD Pro Webcam C920,size=352x288,fps=5
57: name=HD Pro Webcam C920,size=352x288,fps=30
58: name=HD Pro Webcam C920,size=432x240,fps=5
59: name=HD Pro Webcam C920,size=432x240,fps=30
60: name=HD Pro Webcam C920,size=640x360,fps=5
61: name=HD Pro Webcam C920,size=640x360,fps=30
62: name=HD Pro Webcam C920,size=800x448,fps=5
63: name=HD Pro Webcam C920,size=800x448,fps=30
64: name=HD Pro Webcam C920,size=800x600,fps=5
65: name=HD Pro Webcam C920,size=800x600,fps=24
66: name=HD Pro Webcam C920,size=864x480,fps=5
67: name=HD Pro Webcam C920,size=864x480,fps=24
68: name=HD Pro Webcam C920,size=960x720,fps=5
69: name=HD Pro Webcam C920,size=960x720,fps=15
70: name=HD Pro Webcam C920,size=1024x576,fps=5
71: name=HD Pro Webcam C920,size=1024x576,fps=15
72: name=HD Pro Webcam C920,size=1280x720,fps=5
73: name=HD Pro Webcam C920,size=1280x720,fps=10
74: name=HD Pro Webcam C920,size=1600x896,fps=5
75: name=HD Pro Webcam C920,size=1600x896,fps=15/2
76: name=HD Pro Webcam C920,size=1920x1080,fps=5
77: name=HD Pro Webcam C920,size=2304x1296,fps=2
78: name=HD Pro Webcam C920,size=2304x1536,fps=2
79: name=HD Pro Webcam C920,size=640x480,fps=5
80: name=HD Pro Webcam C920,size=640x480,fps=30
81: name=HD Pro Webcam C920,size=160x90,fps=5
82: name=HD Pro Webcam C920,size=160x90,fps=30
83: name=HD Pro Webcam C920,size=160x120,fps=5
84: name=HD Pro Webcam C920,size=160x120,fps=30
85: name=HD Pro Webcam C920,size=176x144,fps=5
86: name=HD Pro Webcam C920,size=176x144,fps=30
87: name=HD Pro Webcam C920,size=320x180,fps=5
88: name=HD Pro Webcam C920,size=320x180,fps=30
89: name=HD Pro Webcam C920,size=320x240,fps=5
90: name=HD Pro Webcam C920,size=320x240,fps=30
91: name=HD Pro Webcam C920,size=352x288,fps=5
92: name=HD Pro Webcam C920,size=352x288,fps=30
93: name=HD Pro Webcam C920,size=432x240,fps=5
94: name=HD Pro Webcam C920,size=432x240,fps=30
95: name=HD Pro Webcam C920,size=640x360,fps=5
96: name=HD Pro Webcam C920,size=640x360,fps=30
97: name=HD Pro Webcam C920,size=800x448,fps=5
98: name=HD Pro Webcam C920,size=800x448,fps=30
99: name=HD Pro Webcam C920,size=800x600,fps=5
100: name=HD Pro Webcam C920,size=800x600,fps=30
101: name=HD Pro Webcam C920,size=864x480,fps=5
102: name=HD Pro Webcam C920,size=864x480,fps=30
103: name=HD Pro Webcam C920,size=960x720,fps=5
104: name=HD Pro Webcam C920,size=960x720,fps=30
105: name=HD Pro Webcam C920,size=1024x576,fps=5
106: name=HD Pro Webcam C920,size=1024x576,fps=30
107: name=HD Pro Webcam C920,size=1280x720,fps=5
108: name=HD Pro Webcam C920,size=1280x720,fps=30
109: name=HD Pro Webcam C920,size=1600x896,fps=5
110: name=HD Pro Webcam C920,size=1600x896,fps=30
111: name=HD Pro Webcam C920,size=1920x1080,fps=5
112: name=HD Pro Webcam C920,size=1920x1080,fps=30
113: name=HD Pro Webcam C920,size=640x480,fps=5
114: name=HD Pro Webcam C920,size=640x480,fps=30
115: name=HD Pro Webcam C920,size=160x90,fps=5
116: name=HD Pro Webcam C920,size=160x90,fps=30
117: name=HD Pro Webcam C920,size=160x120,fps=5
118: name=HD Pro Webcam C920,size=160x120,fps=30
119: name=HD Pro Webcam C920,size=176x144,fps=5
120: name=HD Pro Webcam C920,size=176x144,fps=30
121: name=HD Pro Webcam C920,size=320x180,fps=5
122: name=HD Pro Webcam C920,size=320x180,fps=30
123: name=HD Pro Webcam C920,size=320x240,fps=5
124: name=HD Pro Webcam C920,size=320x240,fps=30
125: name=HD Pro Webcam C920,size=352x288,fps=5
126: name=HD Pro Webcam C920,size=352x288,fps=30
127: name=HD Pro Webcam C920,size=432x240,fps=5
128: name=HD Pro Webcam C920,size=432x240,fps=30
129: name=HD Pro Webcam C920,size=640x360,fps=5
130: name=HD Pro Webcam C920,size=640x360,fps=30
131: name=HD Pro Webcam C920,size=800x448,fps=5
132: name=HD Pro Webcam C920,size=800x448,fps=30
133: name=HD Pro Webcam C920,size=800x600,fps=5
134: name=HD Pro Webcam C920,size=800x600,fps=30
135: name=HD Pro Webcam C920,size=864x480,fps=5
136: name=HD Pro Webcam C920,size=864x480,fps=30
137: name=HD Pro Webcam C920,size=960x720,fps=5
138: name=HD Pro Webcam C920,size=960x720,fps=30
139: name=HD Pro Webcam C920,size=1024x576,fps=5
140: name=HD Pro Webcam C920,size=1024x576,fps=30
141: name=HD Pro Webcam C920,size=1280x720,fps=5
142: name=HD Pro Webcam C920,size=1280x720,fps=30
143: name=HD Pro Webcam C920,size=1600x896,fps=5
144: name=HD Pro Webcam C920,size=1600x896,fps=30
145: name=HD Pro Webcam C920,size=1920x1080,fps=5
146: name=HD Pro Webcam C920,size=1920x1080,fps=30
*/
