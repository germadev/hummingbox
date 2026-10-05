// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '录音机';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get discard => '舍弃';

  @override
  String get create => '创建';

  @override
  String get nameLabel => '名称';

  @override
  String get defaultRecordingName => '录音';

  @override
  String editedCopyName(String name) {
    return '$name（已编辑）';
  }

  @override
  String get loadRecordingsFailed => '无法加载录音';

  @override
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已从文件夹添加 $count 条录音',
    );
    return '$_temp0';
  }

  @override
  String get newFolder => '新建文件夹';

  @override
  String get invalidFolderName => '该名称不能用作文件夹名';

  @override
  String get microphonePermission => '请在设置中允许使用麦克风以进行录音';

  @override
  String get startRecordingFailed => '无法开始录音';

  @override
  String get saveRecordingFailed => '无法保存录音';

  @override
  String savedAs(String name) {
    return '已保存为“$name”';
  }

  @override
  String get discardRecordingTitle => '舍弃这段录音？';

  @override
  String get discardRecordingMessage => '目前已录制的音频将会丢失。';

  @override
  String get stopToPlay => '停止录音后才能播放';

  @override
  String get stopToEdit => '停止录音后才能编辑';

  @override
  String get stopToLeave => '请先停止录音再退出';

  @override
  String get changesSaved => '已保存更改';

  @override
  String get renameFailed => '无法重命名录音';

  @override
  String get shareFailed => '无法分享录音';

  @override
  String deleteTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get deleteMessage => '此操作无法撤销。';

  @override
  String get recordingDeleted => '录音已删除';

  @override
  String get deleteFailed => '无法删除录音';

  @override
  String get settings => '设置';

  @override
  String get rootFolder => '录音';

  @override
  String get savingCopies => '正在保存副本…';

  @override
  String get copiesFailed => '部分副本无法保存';

  @override
  String get emptyFolderTitle => '此文件夹为空';

  @override
  String get emptyFolderHint => '点按红色按钮即可在此录音。';

  @override
  String get noRecordingsTitle => '还没有录音';

  @override
  String get noRecordingsHint => '点按红色按钮开始录音。';

  @override
  String get folders => '文件夹';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get rename => '重命名';

  @override
  String get moreOptions => '更多选项';

  @override
  String get edit => '编辑';

  @override
  String get share => '分享';

  @override
  String dateToday(String time) {
    return '今天 $time';
  }

  @override
  String dateYesterday(String time) {
    return '昨天 $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date $time';
  }

  @override
  String get stereo => '立体声';

  @override
  String channels(int count) {
    return '$count 声道';
  }

  @override
  String bitDepth(int bits) {
    return '$bits 位';
  }

  @override
  String perMinute(String size) {
    return '每分钟 $size';
  }

  @override
  String get renameRecording => '重命名录音';

  @override
  String get hideRecordPanel => '隐藏录音面板';

  @override
  String get showRecordPanel => '显示录音面板';

  @override
  String get countdownStatus => '录音即将开始…';

  @override
  String get waitingForVoice => '等待你开口说话…';

  @override
  String get readyToRecord => '准备录音';

  @override
  String get recordingStatus => '正在录音';

  @override
  String get pausedStatus => '已暂停';

  @override
  String countdownButton(int seconds) {
    return '倒计时 $seconds 秒后录音';
  }

  @override
  String get resume => '继续';

  @override
  String get voiceButton => '检测到说话时开始录音';

  @override
  String get stopAndSave => '停止并保存';

  @override
  String get startNow => '立即开始';

  @override
  String get record => '录音';

  @override
  String get previewFailed => '无法准备试听';

  @override
  String get editSaveFailed => '无法保存编辑';

  @override
  String get discardChangesTitle => '舍弃更改？';

  @override
  String get discardChangesMessage => '未保存的更改将会丢失。';

  @override
  String get editRecording => '编辑录音';

  @override
  String get reset => '重置';

  @override
  String get saving => '正在保存…';

  @override
  String get saveCopy => '另存副本';

  @override
  String get openAudioFailed => '无法打开音频进行编辑。';

  @override
  String get preparingAudio => '正在准备音频…';

  @override
  String get trimStartLabel => '开始';

  @override
  String get durationLabel => '时长';

  @override
  String get trimEndLabel => '结束';

  @override
  String get playSelection => '试听所选部分';

  @override
  String get volume => '音量';

  @override
  String get normalize => '标准化';

  @override
  String get clippingWarning => '最响的部分会失真';

  @override
  String get fadeIn => '淡入';

  @override
  String get fadeOut => '淡出';

  @override
  String get trimStartHandle => '裁剪起点';

  @override
  String get trimEndHandle => '裁剪终点';

  @override
  String get playbackPosition => '播放位置';

  @override
  String get importTitle => '添加该文件夹中的录音？';

  @override
  String importMessage(String folder, int count, String size) {
    return '“$folder”中有 $count 个音频文件（$size）不在应用中。添加后，它们会显示在列表中并复制到应用里。';
  }

  @override
  String get add => '添加';

  @override
  String get dontAdd => '不添加';

  @override
  String get folderFailed => '无法使用该文件夹';

  @override
  String get copiesKept => '文件夹中已有的副本会保留';

  @override
  String get driveConnectFailed => '无法连接 Google Drive';

  @override
  String get disconnectDriveTitle => '断开 Google Drive？';

  @override
  String get disconnectDriveMessage => '将不再向 Drive 保存副本。已有的副本会保留。';

  @override
  String get disconnect => '断开连接';

  @override
  String get format => '格式';

  @override
  String get aacDescription => '压缩格式：占用空间小，任何设备都能播放';

  @override
  String get wavDescription => '无压缩：保真度最高，但占用空间大得多';

  @override
  String get quality => '音质';

  @override
  String get qualityLow => '低';

  @override
  String get qualityMedium => '中';

  @override
  String get qualityHigh => '高';

  @override
  String get countdown => '倒计时';

  @override
  String secondsCount(int seconds) {
    return '$seconds 秒';
  }

  @override
  String countdownSubtitle(int seconds) {
    return '使用倒计时按钮时，开始录音前等待 $seconds 秒';
  }

  @override
  String get recordingSection => '录音';

  @override
  String get formatNote => '适用于新的录音。编辑时，每条录音保留原有格式。';

  @override
  String get storageSection => '录音的保存位置';

  @override
  String get storageDescription =>
      '录音始终保存在应用内。你还可以将每条录音的副本保存到设备上的文件夹和 Google Drive，使用你起的名称并放在对应的子文件夹中。重命名或编辑录音时副本会同步更新，但删除录音时副本不会被删除。';

  @override
  String get deviceFolder => '设备文件夹';

  @override
  String get noFolder => '未保存到任何文件夹';

  @override
  String get stopSavingToFolder => '停止保存到该文件夹';

  @override
  String get chooseAnotherFolder => '选择其他文件夹';

  @override
  String get showFolderRecordings => '显示文件夹中的录音';

  @override
  String get showFolderRecordingsSubtitle => '将文件夹及其子文件夹中的音频（.m4a 和 .wav）添加到应用';

  @override
  String driveAccount(String email, String folder) {
    return '$email · 文件夹“$folder”';
  }

  @override
  String get driveSaveCopy => '将副本保存到你的 Google Drive';

  @override
  String get driveUnavailable => '不可用：此版本的应用未配置 Google 访问权限';

  @override
  String get copyNow => '立即复制';

  @override
  String get copyNowSubtitle => '只复制缺少或有变动的内容';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条录音无法复制',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条录音无法从文件夹添加',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => '无法读取文件夹';

  @override
  String get readRecordingsFailed => '无法读取录音';

  @override
  String get driveReconnect => '请重新连接你的 Google Drive 账号';

  @override
  String get offline => '无网络连接';

  @override
  String get noFolderPermission => '已失去文件夹访问权限，请重新选择。';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message：$detail';
  }
}
