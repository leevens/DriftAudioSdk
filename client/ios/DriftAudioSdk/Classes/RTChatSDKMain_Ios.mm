//
//  RTChatSDKMain.cpp
//  RTChat
//
//  Created by wang3140@hotmail.com on 14-7-29.
//  Copyright (c) 2014年 RTChatTeam. All rights reserved.
//

#include "RTChatSDKMain_Ios.h"
#include "defines.h"
#include "SoundObject.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include "VideoCamera.h"
#include "iflyMSC/IFlySpeechUtility.h"
#include "LocationHelper.h"
#include <MediaPlayer/MediaPlayer.h>

namespace rtchatsdk {
    
    static  RTChatSDKMain* s_RTChatSDKMain = NULL;

    #define MaxBufferSize   1024

    #define SendProtoMsg(MSG, TypeID)   \
        char buff[MaxBufferSize] = {0}; \
        MSG.SerializeToArray(buff, msg.ByteSize()); \
        BUFFER_CMD(stBaseCmd, basecmd, MaxBufferSize);  \
        basecmd->cmdid = TypeID;    \
        basecmd->cmdlen = MSG.ByteSize();   \
        memcpy(basecmd->data, buff, msg.ByteSize());    \
        if (_netDataManager) {  \
            _netDataManager->sendClientMsg((const unsigned char*)basecmd, basecmd->getSize());  \
        }   \

    RTChatSDKMain::RTChatSDKMain() :
    _sdkOpState(SdkControlUnConnected),
    _appid(""),
    _appkey(""),
    _token(""),
    _uniqueid(""),
    _gateWayIP(""),
    _gateWayPort(0),
    _func(NULL),
    _isrecording(false),
    _labelid(0)
    {

    }

    RTChatSDKMain::~RTChatSDKMain()
    {

    }

    RTChatSDKMain& RTChatSDKMain::sharedInstance()
    {
        if (!s_RTChatSDKMain) {
            s_RTChatSDKMain = new RTChatSDKMain();
        }
        
        return *s_RTChatSDKMain;
    }

    SdkErrorCode RTChatSDKMain::initSDK(const std::string &appid, const std::string &key, const char* uniqueid)
    {
        _appid = appid;
        _appkey = key;
        
        if (uniqueid != NULL) {
            _uniqueid = uniqueid;
        }
        
        HttpProcess::instance().registerCallBack(std::bind(&RTChatSDKMain::httpRequestCallBack, this, std::placeholders::_1, std::placeholders::_2));
        
        
        return OPERATION_OK;
    }
    
    /// 设置自定义参数
    void RTChatSDKMain::setParams(const std::string& voiceUploadUrl, const char* xunfeiAppID)
    {
        NSLog(@"voiceUploadUrl:%s", voiceUploadUrl.c_str());
        //创建语音配置,appid必须要传入，仅执行一次则可
        if (xunfeiAppID) {
            NSString *initString = [[NSString alloc] initWithFormat:@"appid=%s,timeout=200000", xunfeiAppID];
            
            //所有服务启动前，需要确保执行createUtility
            [IFlySpeechUtility createUtility:initString];
            
            _isXunfeiInited = true;
        }
        
        _voiceUploadUrl = voiceUploadUrl;
    }

    //注册消息回调
    void RTChatSDKMain::registerMsgCallback(const pMsgCallFunc& func)
    {
        _func = func;
    }

    /// 开始录制麦克风数据
    bool RTChatSDKMain::startRecordVoice(unsigned int labelid, bool needTranslate)
    {
        _labelid = labelid;
        
        _isNeedTranslate = needTranslate;
        
        return [[SoundObject sharedInstance] beginRecord:labelid];
    }

    /// 停止录制麦克风数据
    bool RTChatSDKMain::stopRecordVoice()
    {
        [[SoundObject sharedInstance] stopRecord];
        
        return true;
    }

    /// 开始播放录制数据
    bool RTChatSDKMain::startPlayLocalVoice(unsigned int labelid, const char *voiceUrl)
    {
        NSLog(@"in RTChatSDKMain::startPlayLocalVoice. labelid=%u, url = %s", labelid, voiceUrl);
        if (NSString* filename = [[SoundObject sharedInstance] haveDownloadedurl:[NSString stringWithUTF8String:voiceUrl]]) {
            NSLog(@"找到文件，直接播放");
            [[SoundObject sharedInstance] beginPlayLocalFile:filename];
            _func(enRequestPlay, OPERATION_OK, "");
        }
        else {
            StRequestUrlInfo info(labelid, voiceUrl, VoiceType);
            HttpProcess::instance().requestContent(info);
        }
        
        return true;
    }
    

    /// 停止当前播放录制数据()
    bool RTChatSDKMain::stopPlayLocalVoice()
    {
        [[SoundObject sharedInstance] stopPlay];
        return true;
    }
    
    /// 取消当前录音
    bool RTChatSDKMain::cancelRecordedVoice()
    {
        [[SoundObject sharedInstance] stopRecord];
        
        return true;
    }
    
    /// 设置头像
    bool RTChatSDKMain::setAvater(unsigned int uid, int type)
    {
        VideoCamera* vc = [[VideoCamera alloc] init];
        UIViewController* p_parentVC = [[[UIApplication sharedApplication] keyWindow] rootViewController];
        if (p_parentVC && vc) {
            [vc setCameraMode:EnuPhotoMode];
            [p_parentVC presentViewController:vc animated:YES completion:^{
                vc.uid = uid;
                vc.itype = type;
                vc.uploadUrl = [NSString stringWithUTF8String:_voiceUploadUrl.c_str()];
//                [vc startCamera];
            }];
        }
        return true;
    }
    
    /// 获取头像
    bool RTChatSDKMain::getAvater(unsigned int uid,int type,const char* imageUrl)
    {
        [VideoCamera downloadImgData:[NSString stringWithUTF8String:imageUrl] uid:uid type:type];
        return true;
    }
    
    ///开始摄像
    bool RTChatSDKMain::startRecordVideo(unsigned int labelid, int type)
    {
        VideoCamera* vc = [[VideoCamera alloc] init];
        UIViewController* p_parentVC = [[[UIApplication sharedApplication] keyWindow] rootViewController];
        if (p_parentVC && vc) {
            [vc setCameraMode:EnuVideoMode];
            [p_parentVC presentViewController:vc animated:YES completion:^{
                vc.uid = labelid;
                vc.itype = type;
                [vc startCameraContinuity];
            }];
        }

        return true;
    }
    
    ///播放视频
    bool RTChatSDKMain::playVideo(unsigned int labelid, const char* videoUrl)
    {
//        playVideo(videoUrl);
        StRequestUrlInfo info(labelid, videoUrl, VideoType);
        HttpProcess::instance().requestContent(info);
        return true;
    }
    
    /// 底层音量等级通知
    void RTChatSDKMain::voiceLevelNotify(float power)
    {
        static char buff[1024] = {0};
        bzero(buff, 1024);
        snprintf(buff, 1023, "{\"isok\":\"true\", \"power\":\"%f\"}", power);
        _func(enNotifyRecordPower, OPERATION_OK, buff);
    }
    
    /// 底层播放结束通知
    void RTChatSDKMain::onVoicePlayOver()
    {
        _func(enNotifyPlayOver, OPERATION_OK, "");
    }
    
    
    //上传录制的语音数据
    void RTChatSDKMain::uploadVoiceData(const char *data, unsigned long datasize, unsigned int labelid, unsigned int duration)
    {
        std::map<const char*, const char*> param;
        HttpProcess::instance().postContent(_voiceUploadUrl.c_str(), StCallBackInfo(data, datasize, labelid, _voiceUploadUrl.c_str(), duration), param);
    }

    //录音超过最大时间回调
    void RTChatSDKMain::recordTimeExceed(int time)
    {
        stopRecordVoice();
    }
    
    /// 构造JSON结构数据
    std::string RTChatSDKMain::constructJsonFromData(const StCallBackInfo& info)
    {
        static char buff[1024] = {0};
        bzero(buff, 1024);
        
        snprintf(buff, 1023, "{\"isok\":\"true\", \"url\":\"%s\", \"duration\":\"%u\", \"labelid\":\"%u\"}", info.ptr, info.duration, info.labelid);
        
        return buff;
    }
    
    void RTChatSDKMain::playVideo(const char *fileFullPath)
    {
        MPMoviePlayerViewController* playerView = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:[NSString stringWithUTF8String:fileFullPath]]];
        UIViewController* p_parentVC = [[[UIApplication sharedApplication] keyWindow] rootViewController];
        if (p_parentVC && playerView) {
            [p_parentVC presentViewController:playerView animated:YES completion:nil];
        }
    }
    
    /// 开始处理压缩完成的语音，上传和翻译
    void RTChatSDKMain::beginProcessCompressedVoice()
    {
        NSString* fileName = [SoundObject sharedInstance].current_recordedFile_mp3;
        NSInteger duration = [SoundObject sharedInstance].voiceDuration;
        if (fileName) {
            NSData* data = [NSData dataWithContentsOfFile:fileName];
            if (data) {
                uploadVoiceData((const char *)[data bytes], [data length], _labelid, (unsigned int)duration);
            }
        }
    }
    
    ///开始语音识别
    bool RTChatSDKMain::startVoiceToText()
    {
        if (!_isXunfeiInited) {
            NSLog(@"语音识别引擎未初始化，无法执行");
            return false;
        }
        if (_isrecording) {
            NSLog(@"正在执行识别操作，禁止点击");
            return false;
        }
        [[SoundObject sharedInstance] beginSoundRecognize];
        _isrecording = true;
        return true;
    }
    
    ///停止语音识别
    bool RTChatSDKMain::stopVoiceToText()
    {
        if (!_isXunfeiInited) {
            NSLog(@"语音识别引擎未初始化，无法执行");
            return false;
        }
        
        [[SoundObject sharedInstance] stopSoundRecognize];
        _isrecording = false;
        return true;
    }
    
    /// 获取当前地理位置信息
    bool RTChatSDKMain::startGetCurrentCoordinate()
    {
        _lohelper = [[LocationHelper alloc] init];
        if (_lohelper) {
            [_lohelper requestCurrentEarthPosition:^(NSString *callbackdata) {
                NSLog(@"%@", callbackdata);
                _func(enNotifyCoodinateInfo, OPERATION_OK, [callbackdata UTF8String]);
                _lohelper = nil;
            }];
        }
        
        return true;
    }

    //http请求回调函数(主线程工作)
    void RTChatSDKMain::httpRequestCallBack(HttpDirection direction, const StCallBackInfo& info)
    {
//        static int tempid = 0;
        if (direction == HttpProcess_Upload) {
            if (!info.ptr) {
                //失败
                _func(enRequestRec, OPERATION_FAILED, "");
            }
            else {
                std::string jsondata = constructJsonFromData(info);
                _func(enRequestRec, OPERATION_OK, jsondata);
                
//                startPlayLocalVoice(tempid++, info.ptr);
            }
        }
        else {
            if (!info.ptr) {
                //失败
                //Todo...
                _func(enRequestPlay, OPERATION_FAILED, "");
            }
            else {
                NSData* data = [NSData dataWithBytes:info.ptr length:info.size];
                
                if (info.type == VoiceType) {
                    NSString* outfilename = [[NSString alloc]init];
                    [[SoundObject sharedInstance] saveCacheToDiskFile:[NSString stringWithUTF8String:info.url.c_str()] data:data filename:&outfilename];
                    NSString* pcmfilename = [[SoundObject sharedInstance]transferAmrToPcmFile:outfilename url:[NSString stringWithUTF8String:info.url.c_str()]];
                    if (pcmfilename) {
                        [[SoundObject sharedInstance] beginPlayLocalFile:pcmfilename];
                        _func(enRequestPlay, OPERATION_OK, "");
                    }
                }
                else if (info.type == VideoType) {
                    NSString* fileFullPath = [NSTemporaryDirectory() stringByAppendingFormat:@"recordfile.mp4" ];
                    if ([data writeToFile:fileFullPath atomically:NO]) {
                        playVideo([fileFullPath UTF8String]);
                    }
                }
            }
        }
    }
    
    /// 拍照上传回调接口
    void RTChatSDKMain::onImageUploadOver(bool issuccess, unsigned int uid, int type, const std::string &filename, const std::string &url)
    {
        char buff[1024] = {0};
        bzero(buff, 1024);
        
        snprintf(buff, 1023, "{\"isok\":\"true\", \"url\":\"%s\", \"filepath\":\"%s\", \"uid\":\"%u\", \"itype\":\"%d\"}", url.c_str(), filename.c_str(), uid, type);
        
        if (issuccess) {
            _func(enReqSetAvaterResult, OPERATION_OK, buff);
        }
        else {
            _func(enReqSetAvaterResult, OPERATION_FAILED, "");
        }
    }
    
    /// 图片取回接口
    void RTChatSDKMain::onImageDownloadOver(bool issuccess, unsigned int uid, int type, const std::string& fileName)
    {
        char buff[1024] = {0};
        bzero(buff, 1024);
        
        snprintf(buff, 1023, "{\"isok\":\"true\", \"filepath\":\"%s\", \"uid\":\"%u\", \"itype\":\"%d\"}", fileName.c_str(), uid, type);
        
        if (issuccess) {
            NSLog(@"in onImageDownloadOver success");
            _func(enReqGetAvaterResult, OPERATION_OK, buff);
        }
        else {
            NSLog(@"in onImageDownloadOver failure");
            _func(enReqGetAvaterResult, OPERATION_FAILED, "");
        }
    }
    
    /// 语音听写底层回调
    void RTChatSDKMain::onReceiveVoiceTextResult(const std::string& text)
    {
        char buff[1024] = {0};
        bzero(buff, 1024);
        
        snprintf(buff, 1023, "{\"isok\":\"true\", \"content\":\"%s\", \"labelid\":\"%u\"}", text.c_str(), _labelid);
        _func(enNotifyVoiceTextResult, OPERATION_OK, buff);
    }

    /// 压缩完成回调
    void RTChatSDKMain::onVoiceCompressOver(bool result, const char* fileName)
    {
        if (result) {
            beginProcessCompressedVoice();
            
            if (_isNeedTranslate) {
                [[SoundObject sharedInstance] translateCurrentVoiceData];
            }
        }
        else {
            _func(enRequestRec, OPERATION_FAILED, "");
        }
    }
    
}




