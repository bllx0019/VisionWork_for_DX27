#include<iostream>
#include<ros/ros.h>
#include <sensor_msgs/CompressedImage.h>
#include<opencv2/opencv.hpp>
#include<cv_bridge/cv_bridge.h>
#include<sensor_msgs/image_encodings.h>

using namespace std;

cv::Mat img;
cv::Mat img_hsv;
cv::Mat img_hsv_mask;
cv_bridge::CvImage out_msg_mask;
cv_bridge::CvImage out_msg_debug;

ros::Publisher pub_img;
ros::Publisher pub_img_debug;

void imageCallback(const sensor_msgs::CompressedImage::ConstPtr& img_msg){
    
    if (img_msg->data.empty()) return;
    cv_bridge::CvImagePtr cv_ptr =cv_bridge::toCvCopy(img_msg, sensor_msgs::image_encodings::BGR8);
    img = cv_ptr->image;
    
    cv::cvtColor(img, img_hsv, cv::COLOR_BGR2HSV);
    cv::GaussianBlur(img_hsv, img_hsv, cv::Size(5, 5), 0);
    cv::inRange(img_hsv, cv::Scalar(80, 50, 75), cv::Scalar(115, 255, 255), img_hsv_mask);
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3,3), cv::Point(-1, -1));
    cv::Mat kernel2 = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(5,5), cv::Point(-1, -1));
    cv::morphologyEx(img_hsv_mask, img_hsv_mask, cv::MORPH_OPEN, kernel,cv::Point(-1, -1),2);
    cv::morphologyEx(img_hsv_mask, img_hsv_mask, cv::MORPH_CLOSE, kernel2,cv::Point(-1, -1),2);
    cv::erode(img_hsv_mask, img_hsv_mask, kernel, cv::Point(-1, -1),1);

    vector<vector<cv::Point>> contours;
    cv::findContours(img_hsv_mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    cv::Mat debug_img = img.clone();
    cv::Mat debug_img_mask = img_hsv_mask.clone();
    for (const auto& cnt : contours) {
        
        if (cnt.size() < 5) continue;
        double area = cv::contourArea(cnt);
        if (area < 50 || area > 0.5 * img_hsv_mask.total()) continue;
        
        cv::RotatedRect r = cv::minAreaRect(cnt);
        
        if(std::min(r.size.width, r.size.height) < 2.0f) continue;

        cv::Point2f pts[4];
        r.points(pts);
        for (int i = 0; i < 4; ++i){
            cv::line(debug_img, pts[i], pts[(i + 1) % 4], cv::Scalar(0, 0, 255), 2);
        }
        //ROS_INFO("Ratio: %f", r.size.width/r.size.height);
        float len01 = static_cast<float>(cv::norm(pts[1] - pts[0]));
        float len12 = static_cast<float>(cv::norm(pts[2] - pts[1]));

        cv::Point2f mid1, mid2;
        if (len01 < len12){
            mid1 = (pts[0] + pts[1]) * 0.5f;
            mid2 = (pts[2] + pts[3]) * 0.5f;
        }
    
        else{
        mid1 = (pts[1] + pts[2]) * 0.5f;
        mid2 = (pts[3] + pts[0]) * 0.5f;
        }

        // 画中点 + 短轴中线
        cv::circle(debug_img, mid1, 4, cv::Scalar(0, 255, 0), -1);
        cv::circle(debug_img, mid2, 4, cv::Scalar(0, 255, 0), -1);
        cv::line(debug_img, mid1, mid2, cv::Scalar(255, 0, 255), 1, cv::LINE_AA);
    }

    out_msg_mask.header = img_msg->header;
    out_msg_mask.encoding = sensor_msgs::image_encodings::MONO8;
    out_msg_mask.image = img_hsv_mask;
    pub_img.publish(out_msg_mask.toImageMsg());
    out_msg_debug.header = img_msg->header;
    out_msg_debug.encoding = sensor_msgs::image_encodings::BGR8;
    out_msg_debug.image = debug_img;
    pub_img_debug.publish(out_msg_debug.toImageMsg());

}


int main(int argc, char** argv){
    ros::init(argc, argv,"delection_hsv");
    ros::NodeHandle nh;
    pub_img = nh.advertise<sensor_msgs::Image>("/hk_camera/image_hsv_mask",1);
    pub_img_debug = nh.advertise<sensor_msgs::Image>("/hk_camera/image_hsv_debug",1);
    ros::Subscriber sub_img=nh.subscribe("/hk_camera/image_raw/compressed",1,imageCallback);
    //ros::Subscriber sub_camera_info=nh.subscribe("/hk_camera/camera_info",1,imageCallback);
    ros::spin();
    return 0;
}

