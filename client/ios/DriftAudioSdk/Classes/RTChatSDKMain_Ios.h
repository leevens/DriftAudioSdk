//
//  RTChatSDKMain.h
//  RTChat
//
//  Created by wang3140@hotmail.com on 14-7-29.
//  Copyright (c) 2014年 RTChatTeam. All rights reserved.
//

#ifndef __RTChat__RTChatSDKMain__
#define __RTChat__RTChatSDKMain__

#include <iostream>
#include <map>
#include "RTChatCommonTypes.h"
#include "HttpProcess_Ios.h"

@class LocationHelper;

namespace rtchatsdk {
    
typedef std::function<void (SdkResponseCmd cmdType, SdkErrorCode error, const std::string& msgStr)> pMsgCallFunc;

class RTChatSDKMain {
public:
    RTChatSDKMain();
    virtual ~RTChatSDKMain();
    
    static RTChatSDKMain& sharedInstance();
    
    /*******************需要暴露给用户的接口开始**********************/
    
    //sdk初始化，只能调用一次(主线程)
    SdkErrorCode initSDK(const std::string& appid, const std::string& key, const char* uniqueid = NULL);
    
    /// 设置自定义参数
    void setParams(const std::string& voiceUploadUrl, const char* xunfeiAppID);
    
    //注册消息回调(主线程)
    void registerMsgCallback(const pMsgCallFunc& func);
    
    //获取SDK当前操作状态，用户发起操作前可以检测一下状态判断可否继续
    SdkOpState getSdkState();
    
    /// 开始录制麦克风数据(主线程)
    bool startRecordVoice(unsigned int labelid, bool needTranslate = false);
    
    /// 停止录制麦克风数据(主线程)
    bool stopRecordVoice();
    
    /// 开始播放录制数据(主线程)
    bool startPlayLocalVoice(unsigned int labelid, const char* voiceUrl);
    
    /// 停止当前播放录制数据()
    bool stopPlayLocalVoice();
    
    /// 取消当前录音
    bool cancelRecordedVoice();
    
    /// 设置头像
    bool setAvater(unsigned int uid, int type);
    
    /// 获取头像
    bool getAvater(unsigned int uid, int type, const char* imageUrl);
    
    ///开始摄像
    bool startRecordVideo(unsigned int labelid, int type);
    
    ///播放视频
    bool playVideo(unsigned int labelid, const char* videoUrl);
    
    ///开始语音识别
    bool startVoiceToText();
    
    ///停止语音识别
    bool stopVoiceToText();
    
    /// 获取当前地理位置信息
    bool startGetCurrentCoordinate();
    
    /*******************需要暴露给用户的接口结束**********************/
    
    /// 底层音量等级通知
    void voiceLevelNotify(float power);
    
    /// 底层播放结束通知
    void onVoicePlayOver();
    
    /// http请求回调函数
    void httpRequestCallBack(HttpDirection direction, const StCallBackInfo& info);
    
    /// 拍照上传回调接口
    void onImageUploadOver(bool issuccess, unsigned int uid, int type, const std::string& filename, const std::string& url);
    
    /// 图片取回接口
    void onImageDownloadOver(bool issuccess, unsigned int uid, int type, const std::string& fileName);
    
    /// 语音听写底层回调
    void onReceiveVoiceTextResult(const std::string& text);
    
    /// 压缩完成回调
    void onVoiceCompressOver(bool result, const char* fileName);
    
protected:
    
    //上传录制的语音数据
    void uploadVoiceData(const char *data, unsigned long datasize, unsigned int labelid, unsigned int duration);
    
    //录音超过最大时间回调
    void recordTimeExceed(int time);
    
    /// 构造JSON结构数据
    std::string constructJsonFromData(const StCallBackInfo& info);
    
    /// 播放录制的视频
    void playVideo(const char* fileFullPath);
    
    /// 开始处理压缩完成的语音，上传和翻译
    void beginProcessCompressedVoice();
    
private:
    std::string         _appid;
    std::string         _appkey;
    std::string         _uniqueid;
    std::string         _token;
    std::string         _gateWayIP;       //网关服务器IP
    
    /// 录音上传url
    std::string         _voiceUploadUrl = "";
    
    /// 是否能使用讯飞语音的开关
    bool                _isXunfeiInited = false;
    
    uint32_t            _gateWayPort;     //网关服务器PORT
    
    SdkOpState          _sdkOpState;    //保存SDK操作状态
    
    pMsgCallFunc        _func;          //回调函数

    const char*         _downloadingfileurl; //临时存放下载中的文件名
    
    bool                _isrecording;       //录音标志
    
    LocationHelper*     _lohelper;
    
    bool                _isNeedTranslate;   //录音完是否需要翻译
    
    unsigned int        _labelid;
};
    
}

#endif /* defined(__RTChat__RTChatSDKMain__) */
