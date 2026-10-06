// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'HummingBox';

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
  String editedCopyName(String name) {
    return '$name（編集済み）';
  }

  @override
  String get loadRecordingsFailed => '録音を読み込めませんでした';

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
  String get moveToFolder => 'フォルダに移動';

  @override
  String get moveToTitle => '移動先';

  @override
  String movedTo(String folder) {
    return '「$folder」に移動しました';
  }

  @override
  String get moveFailed => '録音を移動できませんでした';

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
  String get search => '検索';

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get pullToSearch => '引っ張って検索';

  @override
  String get releaseToSearch => '指を離して検索';

  @override
  String get noSearchResultsTitle => '結果なし';

  @override
  String noSearchResultsHint(String query) {
    return '名前や文字起こしに「$query」を含む録音はありません。';
  }

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
  String get folderFailed => 'そのフォルダは使用できません';

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
  String get qualityMinimum => '最低';

  @override
  String get qualityLow => '低';

  @override
  String get qualityMedium => '中';

  @override
  String get qualityHigh => '高';

  @override
  String get qualityVeryHigh => '非常に高い';

  @override
  String get qualityMaximum => '最高';

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
  String get keepScreenOn => '画面をオンのままにする';

  @override
  String get keepScreenOnSubtitle => '録音中や開始を待つ間、システムがアプリを停止しないように';

  @override
  String get recordingSection => '録音';

  @override
  String get formatNote => '新しい録音に適用されます。編集しても各録音の形式は変わりません。';

  @override
  String get storageSection => '録音の保存先';

  @override
  String get deviceFolder => '端末のフォルダ';

  @override
  String get noFolder => 'なし';

  @override
  String get chooseAnotherFolder => '別のフォルダを選ぶ';

  @override
  String driveAccount(String email, String folder) {
    return '$email · フォルダ「$folder」';
  }

  @override
  String get driveSaveCopy => 'Google ドライブにコピーを保存';

  @override
  String get driveUnavailable => '利用できません：このバージョンのアプリは Google へのアクセスが設定されていません';

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の録音を追加できませんでした',
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

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい録音が $count 件あります',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => '録音を再生できませんでした';

  @override
  String deleteFromFolderMessage(String folder) {
    return '「$folder」からも削除されます。この操作は取り消せません。';
  }

  @override
  String get deleteFromDriveMessage => 'Google ドライブのゴミ箱に移動されます。';

  @override
  String get syncing => '同期しています…';

  @override
  String get syncFailed => '一部を同期できませんでした';

  @override
  String get setupTitle => '録音をどこに保存しますか？';

  @override
  String get setupMessage => 'あとで設定から変更できます。';

  @override
  String get setupFolder => 'この端末のフォルダ';

  @override
  String get setupFolderDescription =>
      '内部ストレージ、SD カード、iCloud Drive など。すでに入っている録音もアプリに表示されます。';

  @override
  String get setupDrive => 'Google ドライブ';

  @override
  String get setupDriveDescription =>
      'ドライブ内のフォルダに保存します。まだアップロードできない録音はアプリ内に保存されます。';

  @override
  String get storageFolderDescription =>
      '録音は選んだフォルダに、付けた名前で対応するサブフォルダに保存され、アプリにはその中のすべての音声（.m4a と .wav）が表示されます。アプリで削除・名前変更・編集した内容はフォルダにも反映されます。';

  @override
  String storageDriveDescription(String folder) {
    return '録音は Google ドライブの「$folder」フォルダに保存され、再生や編集のときにダウンロードされます。まだアップロードできていない録音（オフライン時など）はアプリ内に保存されます。端末のフォルダを選ぶと、録音はそこに保存され、ドライブにはコピーが残ります。';
  }

  @override
  String get stopUsingFolder => 'このフォルダの使用をやめる';

  @override
  String stopUsingFolderTitle(String folder) {
    return '「$folder」の使用をやめますか？';
  }

  @override
  String get stopUsingFolderMessage =>
      '録音はフォルダに残りますが、アプリには表示されなくなります。その後、新しい録音の保存先を選ぶ必要があります。';

  @override
  String get stopUsingFolderDriveMessage =>
      '録音はフォルダに残り、アプリは Google ドライブの録音を使うようになります。新しい録音もそこに保存されます。';

  @override
  String get stopUsing => '使用をやめる';

  @override
  String get disconnectDriveStorageMessage =>
      '録音はドライブに残りますが、アプリには表示されなくなります。その後、新しい録音の保存先を選ぶ必要があります。';

  @override
  String folderInUse(String folder) {
    return '録音は「$folder」に保存されるようになりました';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の録音を保存できませんでした',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => 'Google ドライブを読み込めませんでした';

  @override
  String get syncNow => '今すぐ同期';

  @override
  String get syncNowSubtitle => '保留中のものを保存し、録音の保存先の変更を確認します';

  @override
  String get transcribe => '文字起こし';

  @override
  String get viewTranscript => '文字起こしを見る';

  @override
  String transcribingProgress(String percent) {
    return '文字起こし中… $percent';
  }

  @override
  String get preparingTranscription => '文字起こしを準備中…';

  @override
  String get waitingToTranscribe => '文字起こしの待機中…';

  @override
  String get cancelTranscription => '文字起こしをキャンセル';

  @override
  String get transcriptReady => '文字起こしが完了しました';

  @override
  String get view => '表示';

  @override
  String get transcriptionFailed => '録音を文字起こしできませんでした';

  @override
  String get noSpeechRecognized => '言葉を認識できませんでした';

  @override
  String get stopToTranscribe => '文字起こしするには録音を停止してください';

  @override
  String get systemSpeechUnavailableTitle => '音声認識を利用できません';

  @override
  String get systemSpeechUnavailableMessage =>
      'このデバイスではシステムの音声認識で文字起こしできません（Android では 13 以降が必要です）。設定で Whisper をインストールできます。';

  @override
  String unsupportedLanguageMessage(String language) {
    return 'このデバイスのシステム音声認識は「$language」に対応していません。Whisper をインストールするか、設定で別の言語を選んでください。';
  }

  @override
  String get openSettings => '設定を開く';

  @override
  String downloadLanguageTitle(String language) {
    return '「$language」をダウンロードしますか？';
  }

  @override
  String get downloadLanguageMessage =>
      'デバイス上で文字起こしするには、システムの音声認識でこの言語をダウンロードする必要があります。ダウンロードが終わったらもう一度お試しください。';

  @override
  String get download => 'ダウンロード';

  @override
  String get languageDownloading => '言語をダウンロード中です。終わったらもう一度お試しください。';

  @override
  String get speechPermission => '文字起こしするには設定で音声認識を許可してください';

  @override
  String get whisperNotInstalledTitle => 'Whisper がインストールされていません';

  @override
  String get whisperNotInstalledMessage =>
      'Whisper で文字起こしするには、設定でモデルをダウンロードしてください。';

  @override
  String get copy => 'コピー';

  @override
  String get copied => 'クリップボードにコピーしました';

  @override
  String get transcribeAgain => 'もう一度文字起こし';

  @override
  String get transcribeInLanguage => '別の言語で文字起こし';

  @override
  String get recordingLanguage => '録音の言語';

  @override
  String get sameAsSettings => '設定と同じ';

  @override
  String get deleteTranscript => '文字起こしを削除';

  @override
  String get transcriptDeleted => '文字起こしを削除しました';

  @override
  String get transcriptOutdated => '文字起こしの後に録音が変更されました。';

  @override
  String get transcriptionSection => '文字起こし';

  @override
  String get transcriptionEngine => '文字起こしの方法';

  @override
  String get autoTranscribe => '自動で文字起こし';

  @override
  String get autoTranscribeSubtitle => 'まだ文字起こしされていない録音をバックグラウンドで処理します';

  @override
  String get autoTranscriptionFailed => '録音を自動で文字起こしできません';

  @override
  String get systemSpeechRecognition => 'システムの音声認識';

  @override
  String get systemSpeechDescription => 'ダウンロード不要。Android では 13 以降が必要';

  @override
  String get whisperDescription => 'デバイス上でオフライン動作。モデルのダウンロードが必要';

  @override
  String get whisperModel => 'Whisper モデル';

  @override
  String get whisperNotInstalled => '未インストール。タップしてダウンロード';

  @override
  String whisperInstalled(String model, String size) {
    return 'インストール済み: $model（$size）';
  }

  @override
  String whisperDownloading(String model, String percent, String size) {
    return '$model をダウンロード中… $size 中 $percent';
  }

  @override
  String get whisperDownloadFailed => 'モデルをダウンロードできませんでした';

  @override
  String get chooseWhisperModel => 'モデルをダウンロード';

  @override
  String whisperTinyDescription(String size) {
    return '$size · 高速、精度は低め';
  }

  @override
  String whisperBaseDescription(String size) {
    return '$size · 高精度、やや低速';
  }

  @override
  String get deleteWhisperModel => 'モデルを削除';

  @override
  String get deleteWhisperModelTitle => 'Whisper モデルを削除しますか？';

  @override
  String deleteWhisperModelMessage(String size) {
    return '$size が解放されます。後でもう一度ダウンロードできます。';
  }

  @override
  String get cancelDownload => 'ダウンロードをキャンセル';

  @override
  String get transcriptionLanguage => '言語';

  @override
  String appLanguageOption(String language) {
    return 'アプリの言語（$language）';
  }

  @override
  String get detectLanguageOption => '自動検出（Whisper のみ）';

  @override
  String get searchSection => '検索';

  @override
  String get similarWords => '似た単語も含める';

  @override
  String get similarWordsSubtitle => '入力ミスや語形の違いがあっても見つけます（ラテン文字の言語のみ）';

  @override
  String get appearanceSection => '外観';

  @override
  String get theme => 'テーマ';

  @override
  String get themeSystem => '自動（システムに合わせる）';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get renameToTranscriptTitle => '録音の名前を変更しますか？';

  @override
  String renameToTranscriptMessage(String current, String name) {
    return '新しい文字起こしにより、「$current」は「$name」という名前になります。';
  }

  @override
  String get keepName => 'そのまま';

  @override
  String get piano => 'ピアノ';

  @override
  String get pianoHint => '鍵盤をタップすると音が鳴ります。\n小さな鍵盤をスワイプすると移動できます。';

  @override
  String get noteNames => 'C D E F G A B';

  @override
  String get close => '閉じる';

  @override
  String get pianoAlwaysRecorded => 'ピアノは常に録音されます';

  @override
  String get pianoAndVoice => 'ピアノと声';

  @override
  String get pianoNothingPlayed => '保存するものがありません：音が弾かれていません';

  @override
  String get pianoTurnAround => '上下を反転';

  @override
  String get instrument => '楽器';

  @override
  String get instrumentPiano => 'ピアノ';

  @override
  String get instrumentOrgan => 'オルガン';

  @override
  String get instrumentGuitar => 'ギター';

  @override
  String get instrumentMarimba => 'マリンバ';

  @override
  String get instrumentSynth => 'シンセサイザー';

  @override
  String get synthWave => '波形';

  @override
  String get waveSaw => 'ノコギリ波';

  @override
  String get waveSquare => '矩形波';

  @override
  String get waveTriangle => '三角波';

  @override
  String get waveSine => 'サイン波';

  @override
  String get synthAttack => 'アタック';

  @override
  String get synthDecay => 'ディケイ';

  @override
  String get synthSustain => 'サステイン';

  @override
  String get synthRelease => 'リリース';

  @override
  String get synthBrightness => '明るさ';

  @override
  String get synthResonance => 'レゾナンス';

  @override
  String get synthDetune => 'デチューン';

  @override
  String get synthReset => 'デフォルトの音色';

  @override
  String get stopPlayback => '再生を停止';

  @override
  String get playAll => '続けて再生';

  @override
  String get repeat => 'リピート';

  @override
  String get compactView => 'コンパクト表示';

  @override
  String get detailedView => '詳細表示';

  @override
  String get addPiano => 'ピアノを追加';

  @override
  String pianoOver(String name) {
    return '「$name」に合わせて';
  }

  @override
  String pianoAdded(String name) {
    return '「$name」にピアノを追加しました';
  }
}
