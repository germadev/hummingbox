// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ボイスレコーダー';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get discard => '破棄';

  @override
  String get create => '作成';

  @override
  String get nameLabel => '名前';

  @override
  String get defaultRecordingName => '録音';

  @override
  String editedCopyName(String name) {
    return '$name（編集済み）';
  }

  @override
  String get loadRecordingsFailed => '録音を読み込めませんでした';

  @override
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'フォルダから $count 件の録音を追加しました',
    );
    return '$_temp0';
  }

  @override
  String get newFolder => '新しいフォルダ';

  @override
  String get invalidFolderName => 'その名前はフォルダに使えません';

  @override
  String get microphonePermission => '録音するには設定でマイクへのアクセスを許可してください';

  @override
  String get startRecordingFailed => '録音を開始できませんでした';

  @override
  String get saveRecordingFailed => '録音を保存できませんでした';

  @override
  String savedAs(String name) {
    return '「$name」として保存しました';
  }

  @override
  String get discardRecordingTitle => '録音を破棄しますか？';

  @override
  String get discardRecordingMessage => 'これまでに録音した音声は失われます。';

  @override
  String get stopToPlay => '再生するには録音を停止してください';

  @override
  String get stopToEdit => '編集するには録音を停止してください';

  @override
  String get stopToLeave => '終了する前に録音を停止してください';

  @override
  String get changesSaved => '変更を保存しました';

  @override
  String get renameFailed => '録音の名前を変更できませんでした';

  @override
  String get shareFailed => '録音を共有できませんでした';

  @override
  String deleteTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get deleteMessage => 'この操作は取り消せません。';

  @override
  String get recordingDeleted => '録音を削除しました';

  @override
  String get deleteFailed => '録音を削除できませんでした';

  @override
  String get settings => '設定';

  @override
  String get rootFolder => '録音';

  @override
  String get savingCopies => 'コピーを保存中…';

  @override
  String get copiesFailed => '一部のコピーを保存できませんでした';

  @override
  String get emptyFolderTitle => 'このフォルダは空です';

  @override
  String get emptyFolderHint => '赤いボタンをタップすると、ここに録音します。';

  @override
  String get noRecordingsTitle => 'まだ録音がありません';

  @override
  String get noRecordingsHint => '赤いボタンをタップして録音を開始します。';

  @override
  String get folders => 'フォルダ';

  @override
  String get play => '再生';

  @override
  String get pause => '一時停止';

  @override
  String get rename => '名前を変更';

  @override
  String get moreOptions => 'その他のオプション';

  @override
  String get edit => '編集';

  @override
  String get share => '共有';

  @override
  String dateToday(String time) {
    return '今日 $time';
  }

  @override
  String dateYesterday(String time) {
    return '昨日 $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date $time';
  }

  @override
  String get stereo => 'ステレオ';

  @override
  String channels(int count) {
    return '$count チャンネル';
  }

  @override
  String bitDepth(int bits) {
    return '$bits ビット';
  }

  @override
  String perMinute(String size) {
    return '1 分あたり $size';
  }

  @override
  String get renameRecording => '録音の名前を変更';

  @override
  String get hideRecordPanel => '録音パネルを隠す';

  @override
  String get showRecordPanel => '録音パネルを表示';

  @override
  String get countdownStatus => '録音開始まで…';

  @override
  String get waitingForVoice => '話し始めるのを待っています…';

  @override
  String get readyToRecord => '録音できます';

  @override
  String get recordingStatus => '録音中';

  @override
  String get pausedStatus => '一時停止中';

  @override
  String countdownButton(int seconds) {
    return '$seconds 秒のカウントダウン後に録音';
  }

  @override
  String get resume => '再開';

  @override
  String get voiceButton => '話し始めたら録音';

  @override
  String get stopAndSave => '停止して保存';

  @override
  String get startNow => '今すぐ開始';

  @override
  String get record => '録音';

  @override
  String get previewFailed => '試聴を準備できませんでした';

  @override
  String get editSaveFailed => '編集を保存できませんでした';

  @override
  String get discardChangesTitle => '変更を破棄しますか？';

  @override
  String get discardChangesMessage => '保存していない変更は失われます。';

  @override
  String get editRecording => '録音を編集';

  @override
  String get reset => 'リセット';

  @override
  String get saving => '保存中…';

  @override
  String get saveCopy => 'コピーを保存';

  @override
  String get openAudioFailed => '編集のために音声を開けませんでした。';

  @override
  String get preparingAudio => '音声を準備中…';

  @override
  String get trimStartLabel => '開始';

  @override
  String get durationLabel => '長さ';

  @override
  String get trimEndLabel => '終了';

  @override
  String get playSelection => '選択範囲を再生';

  @override
  String get volume => '音量';

  @override
  String get normalize => 'ノーマライズ';

  @override
  String get clippingWarning => '大きな部分が音割れします';

  @override
  String get fadeIn => 'フェードイン';

  @override
  String get fadeOut => 'フェードアウト';

  @override
  String get trimStartHandle => 'トリミングの開始';

  @override
  String get trimEndHandle => 'トリミングの終了';

  @override
  String get playbackPosition => '再生位置';

  @override
  String get importTitle => 'フォルダの録音を追加しますか？';

  @override
  String importMessage(String folder, int count, String size) {
    return '「$folder」には、アプリにない音声ファイルが $count 件（$size）あります。追加すると一覧に表示され、アプリにコピーされます。';
  }

  @override
  String get add => '追加';

  @override
  String get dontAdd => '追加しない';

  @override
  String get folderFailed => 'そのフォルダは使用できません';

  @override
  String get copiesKept => 'フォルダ内の既存のコピーは残ります';

  @override
  String get driveConnectFailed => 'Google ドライブに接続できませんでした';

  @override
  String get disconnectDriveTitle => 'Google ドライブとの接続を解除しますか？';

  @override
  String get disconnectDriveMessage => 'Drive へのコピーの保存を停止します。既存のコピーは残ります。';

  @override
  String get disconnect => '接続を解除';

  @override
  String get format => '形式';

  @override
  String get aacDescription => '圧縮：容量が小さく、どの端末でも再生できます';

  @override
  String get wavDescription => '非圧縮：最高の音質ですが、容量がずっと大きくなります';

  @override
  String get quality => '音質';

  @override
  String get qualityLow => '低';

  @override
  String get qualityMedium => '中';

  @override
  String get qualityHigh => '高';

  @override
  String get countdown => 'カウントダウン';

  @override
  String secondsCount(int seconds) {
    return '$seconds 秒';
  }

  @override
  String countdownSubtitle(int seconds) {
    return 'カウントダウンボタンで録音を始めるまで $seconds 秒';
  }

  @override
  String get recordingSection => '録音';

  @override
  String get formatNote => '新しい録音に適用されます。編集しても各録音の形式は変わりません。';

  @override
  String get storageSection => '録音の保存先';

  @override
  String get storageDescription =>
      '録音は常にアプリ内に保存されます。さらに、端末のフォルダや Google ドライブに、付けた名前のまま対応するサブフォルダへコピーを保存できます。録音の名前を変えたり編集したりするとコピーも更新されますが、録音を削除してもコピーは削除されません。';

  @override
  String get deviceFolder => '端末のフォルダ';

  @override
  String get noFolder => 'どのフォルダにも保存しません';

  @override
  String get stopSavingToFolder => 'フォルダへの保存をやめる';

  @override
  String get chooseAnotherFolder => '別のフォルダを選ぶ';

  @override
  String get showFolderRecordings => 'フォルダの録音を表示';

  @override
  String get showFolderRecordingsSubtitle =>
      'フォルダとサブフォルダ内の音声ファイル（.m4a と .wav）をアプリに追加します';

  @override
  String driveAccount(String email, String folder) {
    return '$email · フォルダ「$folder」';
  }

  @override
  String get driveSaveCopy => 'Google ドライブにコピーを保存';

  @override
  String get driveUnavailable => '利用できません：このバージョンのアプリは Google へのアクセスが設定されていません';

  @override
  String get copyNow => '今すぐコピー';

  @override
  String get copyNowSubtitle => '不足分や変更分のみコピーします';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の録音をコピーできませんでした',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'フォルダから $count 件の録音を追加できませんでした',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => 'フォルダを読み取れませんでした';

  @override
  String get readRecordingsFailed => '録音を読み取れませんでした';

  @override
  String get driveReconnect => 'Google ドライブのアカウントを再接続してください';

  @override
  String get offline => '接続なし';

  @override
  String get noFolderPermission => 'フォルダへのアクセス許可がなくなりました。もう一度選択してください。';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message：$detail';
  }
}
