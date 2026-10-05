// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'HummingBox';

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
  String editedCopyName(String name) {
    return '$name（已编辑）';
  }

  @override
  String get loadRecordingsFailed => '无法加载录音';

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
  String get search => '搜索';

  @override
  String get searchHint => '名称或转写内容';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get pullToSearch => '下拉搜索';

  @override
  String get releaseToSearch => '松开即可搜索';

  @override
  String get noSearchResultsTitle => '无结果';

  @override
  String noSearchResultsHint(String query) {
    return '没有录音的名称或转写内容包含“$query”。';
  }

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
  String get folderFailed => '无法使用该文件夹';

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
  String get keepScreenOn => '保持屏幕常亮';

  @override
  String get keepScreenOnSubtitle => '录音或等待开始时，以免系统停止应用';

  @override
  String get recordingSection => '录音';

  @override
  String get formatNote => '适用于新的录音。编辑时，每条录音保留原有格式。';

  @override
  String get storageSection => '录音的保存位置';

  @override
  String get deviceFolder => '设备文件夹';

  @override
  String get noFolder => '无';

  @override
  String get chooseAnotherFolder => '选择其他文件夹';

  @override
  String driveAccount(String email, String folder) {
    return '$email · 文件夹“$folder”';
  }

  @override
  String get driveSaveCopy => '将副本保存到你的 Google Drive';

  @override
  String get driveUnavailable => '不可用：此版本的应用未配置 Google 访问权限';

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条录音未能添加',
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

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条新录音',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => '无法播放录音';

  @override
  String deleteFromFolderMessage(String folder) {
    return '它也会从“$folder”中删除。此操作无法撤销。';
  }

  @override
  String get deleteFromDriveMessage => '它将被移到你的 Google Drive 回收站。';

  @override
  String get syncing => '正在同步…';

  @override
  String get syncFailed => '部分内容未能同步';

  @override
  String get setupTitle => '你想把录音保存在哪里？';

  @override
  String get setupMessage => '之后可以在设置中更改。';

  @override
  String get setupFolder => '设备上的文件夹';

  @override
  String get setupFolderDescription => '内部存储、SD 卡、iCloud 云盘……其中已有的录音会显示在应用中。';

  @override
  String get setupDrive => 'Google Drive';

  @override
  String get setupDriveDescription => '保存在你 Drive 的一个文件夹中。暂时无法上传的录音会保存在应用内。';

  @override
  String get storageFolderDescription =>
      '录音保存在所选文件夹中，使用你起的名称并放在对应的子文件夹里，应用会显示其中的所有音频（.m4a 和 .wav）。在应用中删除、重命名或编辑的内容也会同步到文件夹。';

  @override
  String storageDriveDescription(String folder) {
    return '录音保存在你的 Google Drive 的“$folder”文件夹中，播放或编辑时会下载。尚未上传的录音（例如离线时）会保存在应用内。如果选择设备上的文件夹，录音会保存在那里，Drive 中保留一份副本。';
  }

  @override
  String get stopUsingFolder => '停止使用此文件夹';

  @override
  String stopUsingFolderTitle(String folder) {
    return '停止使用“$folder”？';
  }

  @override
  String get stopUsingFolderMessage => '录音会保留在文件夹中，但不再显示在应用里。之后你需要选择新录音的保存位置。';

  @override
  String get stopUsingFolderDriveMessage =>
      '录音会保留在文件夹中，应用将改用你 Google Drive 中的录音，新录音也会保存在那里。';

  @override
  String get stopUsing => '停止使用';

  @override
  String get disconnectDriveStorageMessage =>
      '录音会保留在你的 Drive 中，但不再显示在应用里。之后你需要选择新录音的保存位置。';

  @override
  String folderInUse(String folder) {
    return '录音现在保存在“$folder”中';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条录音未能保存',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => '无法读取 Google Drive';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncNowSubtitle => '保存待处理的内容，并检查录音保存位置的更改';

  @override
  String get transcribe => '转写';

  @override
  String get viewTranscript => '查看转写';

  @override
  String transcribingProgress(String percent) {
    return '正在转写… $percent';
  }

  @override
  String get preparingTranscription => '正在准备转写…';

  @override
  String get waitingToTranscribe => '等待转写…';

  @override
  String get cancelTranscription => '取消转写';

  @override
  String get transcriptReady => '转写完成';

  @override
  String get view => '查看';

  @override
  String get transcriptionFailed => '无法转写录音';

  @override
  String get noSpeechRecognized => '未识别到任何文字';

  @override
  String get stopToTranscribe => '停止录音后才能转写';

  @override
  String get systemSpeechUnavailableTitle => '语音识别不可用';

  @override
  String get systemSpeechUnavailableMessage =>
      '此设备无法使用系统语音识别进行转写（Android 需要 13 或更高版本）。你可以在设置中安装 Whisper。';

  @override
  String unsupportedLanguageMessage(String language) {
    return '此设备上的系统语音识别不支持“$language”。你可以安装 Whisper，或在设置中选择其他语言。';
  }

  @override
  String get openSettings => '打开设置';

  @override
  String downloadLanguageTitle(String language) {
    return '下载“$language”？';
  }

  @override
  String get downloadLanguageMessage => '系统语音识别需要下载此语言才能在设备上转写。下载完成后请重试。';

  @override
  String get download => '下载';

  @override
  String get languageDownloading => '语言仍在下载中。下载完成后请重试。';

  @override
  String get speechPermission => '请在设置中允许语音识别以进行转写';

  @override
  String get whisperNotInstalledTitle => '未安装 Whisper';

  @override
  String get whisperNotInstalledMessage => '要使用 Whisper 转写，请在设置中下载模型。';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制到剪贴板';

  @override
  String get transcribeAgain => '重新转写';

  @override
  String get transcribeInLanguage => '用其他语言转写';

  @override
  String get recordingLanguage => '录音的语言';

  @override
  String get sameAsSettings => '与设置相同';

  @override
  String get deleteTranscript => '删除转写';

  @override
  String get transcriptDeleted => '已删除转写';

  @override
  String get transcriptOutdated => '录音在转写后已更改。';

  @override
  String get transcriptionSection => '转写';

  @override
  String get transcriptionEngine => '转写方式';

  @override
  String get autoTranscribe => '自动转写';

  @override
  String get autoTranscribeSubtitle => '在后台转写还没有转写文本的录音';

  @override
  String get autoTranscriptionFailed => '无法自动转写录音';

  @override
  String get systemSpeechRecognition => '系统语音识别';

  @override
  String get systemSpeechDescription => '无需下载。Android 需要 13 或更高版本';

  @override
  String get whisperDescription => '在设备上离线运行。需要下载模型';

  @override
  String get whisperModel => 'Whisper 模型';

  @override
  String get whisperNotInstalled => '未安装。点按以下载';

  @override
  String whisperInstalled(String model, String size) {
    return '已安装：$model（$size）';
  }

  @override
  String whisperDownloading(String model, String percent, String size) {
    return '正在下载 $model… $size 中的 $percent';
  }

  @override
  String get whisperDownloadFailed => '无法下载模型';

  @override
  String get chooseWhisperModel => '下载模型';

  @override
  String whisperTinyDescription(String size) {
    return '$size · 更快，准确度较低';
  }

  @override
  String whisperBaseDescription(String size) {
    return '$size · 更准确，速度较慢';
  }

  @override
  String get deleteWhisperModel => '删除模型';

  @override
  String get deleteWhisperModelTitle => '删除 Whisper 模型？';

  @override
  String deleteWhisperModelMessage(String size) {
    return '这将释放 $size。之后可以重新下载。';
  }

  @override
  String get cancelDownload => '取消下载';

  @override
  String get transcriptionLanguage => '语言';

  @override
  String appLanguageOption(String language) {
    return '应用语言（$language）';
  }

  @override
  String get detectLanguageOption => '自动检测（仅限 Whisper）';

  @override
  String get searchSection => '搜索';

  @override
  String get similarWords => '包括相似的词';

  @override
  String get similarWordsSubtitle => '也查找有拼写错误或词形变化的词（仅限拉丁字母语言）';

  @override
  String get appearanceSection => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '自动（跟随系统）';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get renameToTranscriptTitle => '重命名录音？';

  @override
  String renameToTranscriptMessage(String current, String name) {
    return '根据新的转写内容，“$current”将改名为“$name”。';
  }

  @override
  String get keepName => '保留原名';

  @override
  String get piano => '钢琴';

  @override
  String get pianoHint => '点按琴键即可听到音符。\n在小键盘上滑动可移动位置。';

  @override
  String get noteNames => 'C D E F G A B';

  @override
  String get close => '关闭';
}
