// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'HummingBox';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Salvar';

  @override
  String get delete => 'Excluir';

  @override
  String get discard => 'Descartar';

  @override
  String get create => 'Criar';

  @override
  String get nameLabel => 'Nome';

  @override
  String get defaultRecordingName => 'Gravação';

  @override
  String editedCopyName(String name) {
    return '$name (editada)';
  }

  @override
  String get loadRecordingsFailed => 'Não foi possível carregar as gravações';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get invalidFolderName => 'Esse nome não é válido para uma pasta';

  @override
  String get microphonePermission =>
      'Permita o acesso ao microfone nas configurações para gravar';

  @override
  String get startRecordingFailed => 'Não foi possível iniciar a gravação';

  @override
  String get saveRecordingFailed => 'Não foi possível salvar a gravação';

  @override
  String savedAs(String name) {
    return 'Salva como “$name”';
  }

  @override
  String get discardRecordingTitle => 'Descartar a gravação?';

  @override
  String get discardRecordingMessage =>
      'O áudio gravado até agora será perdido.';

  @override
  String get stopToPlay => 'Pare a gravação para reproduzir';

  @override
  String get stopToEdit => 'Pare a gravação para editar';

  @override
  String get stopToLeave => 'Pare a gravação antes de sair';

  @override
  String get changesSaved => 'Alterações salvas';

  @override
  String get renameFailed => 'Não foi possível renomear a gravação';

  @override
  String get shareFailed => 'Não foi possível compartilhar a gravação';

  @override
  String deleteTitle(String name) {
    return 'Excluir “$name”?';
  }

  @override
  String get deleteMessage => 'Esta ação não pode ser desfeita.';

  @override
  String get recordingDeleted => 'Gravação excluída';

  @override
  String get deleteFailed => 'Não foi possível excluir a gravação';

  @override
  String get settings => 'Configurações';

  @override
  String get rootFolder => 'Gravações';

  @override
  String get emptyFolderTitle => 'Esta pasta está vazia';

  @override
  String get emptyFolderHint => 'Toque no botão vermelho para gravar nela.';

  @override
  String get noRecordingsTitle => 'Ainda não há gravações';

  @override
  String get noRecordingsHint =>
      'Toque no botão vermelho para começar a gravar.';

  @override
  String get folders => 'Pastas';

  @override
  String get search => 'Pesquisar';

  @override
  String get searchHint => 'Nome ou transcrição';

  @override
  String get clearSearch => 'Limpar a pesquisa';

  @override
  String get pullToSearch => 'Puxe para pesquisar';

  @override
  String get releaseToSearch => 'Solte para pesquisar';

  @override
  String get noSearchResultsTitle => 'Nenhum resultado';

  @override
  String noSearchResultsHint(String query) {
    return 'Nenhuma gravação tem “$query” no nome ou na transcrição.';
  }

  @override
  String get play => 'Reproduzir';

  @override
  String get pause => 'Pausar';

  @override
  String get rename => 'Renomear';

  @override
  String get moreOptions => 'Mais opções';

  @override
  String get edit => 'Editar';

  @override
  String get share => 'Compartilhar';

  @override
  String dateToday(String time) {
    return 'Hoje, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Ontem, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get stereo => 'estéreo';

  @override
  String channels(int count) {
    return '$count canais';
  }

  @override
  String bitDepth(int bits) {
    return '$bits bits';
  }

  @override
  String perMinute(String size) {
    return '$size por minuto';
  }

  @override
  String get renameRecording => 'Renomear gravação';

  @override
  String get hideRecordPanel => 'Ocultar o painel de gravação';

  @override
  String get showRecordPanel => 'Mostrar o painel de gravação';

  @override
  String get countdownStatus => 'A gravação começa em…';

  @override
  String get waitingForVoice => 'Esperando você falar…';

  @override
  String get readyToRecord => 'Pronto para gravar';

  @override
  String get recordingStatus => 'Gravando';

  @override
  String get pausedStatus => 'Em pausa';

  @override
  String countdownButton(int seconds) {
    return 'Gravar após uma contagem regressiva de $seconds s';
  }

  @override
  String get resume => 'Retomar';

  @override
  String get voiceButton => 'Gravar ao detectar a voz';

  @override
  String get stopAndSave => 'Parar e salvar';

  @override
  String get startNow => 'Começar agora';

  @override
  String get record => 'Gravar';

  @override
  String get previewFailed => 'Não foi possível preparar a prévia';

  @override
  String get editSaveFailed => 'Não foi possível salvar a edição';

  @override
  String get discardChangesTitle => 'Descartar as alterações?';

  @override
  String get discardChangesMessage =>
      'As alterações não salvas serão perdidas.';

  @override
  String get editRecording => 'Editar gravação';

  @override
  String get reset => 'Redefinir';

  @override
  String get saving => 'Salvando…';

  @override
  String get saveCopy => 'Salvar cópia';

  @override
  String get openAudioFailed => 'Não foi possível abrir o áudio para editá-lo.';

  @override
  String get preparingAudio => 'Preparando o áudio…';

  @override
  String get trimStartLabel => 'Início';

  @override
  String get durationLabel => 'Duração';

  @override
  String get trimEndLabel => 'Fim';

  @override
  String get playSelection => 'Ouvir a seleção';

  @override
  String get volume => 'Volume';

  @override
  String get normalize => 'Normalizar';

  @override
  String get clippingWarning => 'As partes mais altas vão saturar';

  @override
  String get fadeIn => 'Fade in';

  @override
  String get fadeOut => 'Fade out';

  @override
  String get trimStartHandle => 'Início do corte';

  @override
  String get trimEndHandle => 'Fim do corte';

  @override
  String get playbackPosition => 'Posição da reprodução';

  @override
  String get folderFailed => 'Não foi possível usar essa pasta';

  @override
  String get driveConnectFailed => 'Não foi possível conectar ao Google Drive';

  @override
  String get disconnectDriveTitle => 'Desconectar o Google Drive?';

  @override
  String get disconnectDriveMessage =>
      'As cópias deixarão de ser salvas no Drive. As que já estão lá são mantidas.';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get format => 'Formato';

  @override
  String get aacDescription =>
      'Comprimido: ocupa pouco espaço e toca em qualquer dispositivo';

  @override
  String get wavDescription =>
      'Sem compressão: máxima fidelidade, mas ocupa muito mais espaço';

  @override
  String get quality => 'Qualidade';

  @override
  String get qualityLow => 'Baixa';

  @override
  String get qualityMedium => 'Média';

  @override
  String get qualityHigh => 'Alta';

  @override
  String get countdown => 'Contagem regressiva';

  @override
  String secondsCount(int seconds) {
    return '$seconds segundos';
  }

  @override
  String countdownSubtitle(int seconds) {
    return '$seconds segundos antes de começar a gravar com o botão de contagem regressiva';
  }

  @override
  String get keepScreenOn => 'Manter a tela ligada';

  @override
  String get keepScreenOnSubtitle =>
      'Enquanto grava ou espera para começar, para que o sistema não pare o app';

  @override
  String get recordingSection => 'Gravação';

  @override
  String get formatNote =>
      'Aplica-se às novas gravações. Ao editar, cada gravação mantém seu formato.';

  @override
  String get storageSection => 'Onde as gravações são salvas';

  @override
  String get deviceFolder => 'Pasta do dispositivo';

  @override
  String get noFolder => 'Nenhuma';

  @override
  String get chooseAnotherFolder => 'Escolher outra pasta';

  @override
  String driveAccount(String email, String folder) {
    return '$email · pasta “$folder”';
  }

  @override
  String get driveSaveCopy => 'Salvar uma cópia no seu Google Drive';

  @override
  String get driveUnavailable =>
      'Indisponível: esta versão do app não está configurada para acessar o Google';

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível adicionar $count gravações',
      one: 'Não foi possível adicionar 1 gravação',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => 'Não foi possível ler a pasta';

  @override
  String get readRecordingsFailed => 'Não foi possível ler as gravações';

  @override
  String get driveReconnect => 'Conecte novamente sua conta do Google Drive';

  @override
  String get offline => 'Sem conexão';

  @override
  String get noFolderPermission =>
      'Não há mais permissão para a pasta. Escolha-a novamente.';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message: $detail';
  }

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gravações novas',
      one: '1 gravação nova',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => 'Não foi possível reproduzir a gravação';

  @override
  String deleteFromFolderMessage(String folder) {
    return 'Ela também será excluída de “$folder”. Esta ação não pode ser desfeita.';
  }

  @override
  String get deleteFromDriveMessage =>
      'Ela será movida para a lixeira do seu Google Drive.';

  @override
  String get syncing => 'Sincronizando…';

  @override
  String get syncFailed => 'Não foi possível sincronizar tudo';

  @override
  String get setupTitle => 'Onde você quer salvar as gravações?';

  @override
  String get setupMessage => 'Você pode mudar isso depois nas configurações.';

  @override
  String get setupFolder => 'Em uma pasta do dispositivo';

  @override
  String get setupFolderDescription =>
      'No armazenamento interno, em um cartão SD, no iCloud Drive… As gravações que já estiverem nela aparecerão no app.';

  @override
  String get setupDrive => 'No Google Drive';

  @override
  String get setupDriveDescription =>
      'Em uma pasta do seu Drive. As que ainda não puderem ser enviadas ficam salvas no app.';

  @override
  String get storageFolderDescription =>
      'As gravações são salvas na pasta escolhida, com o nome que você der e na subpasta delas, e o app mostra todos os áudios (.m4a e .wav) que estão nela. O que você excluir, renomear ou editar no app também muda na pasta.';

  @override
  String storageDriveDescription(String folder) {
    return 'As gravações são salvas na pasta “$folder” do seu Google Drive e baixadas para ouvir ou editar. As que ainda não puderam ser enviadas (por exemplo, sem conexão) ficam salvas no app. Se você escolher uma pasta do dispositivo, elas serão salvas nela e o Drive guardará uma cópia.';
  }

  @override
  String get stopUsingFolder => 'Deixar de usar a pasta';

  @override
  String stopUsingFolderTitle(String folder) {
    return 'Deixar de usar “$folder”?';
  }

  @override
  String get stopUsingFolderMessage =>
      'As gravações ficarão na pasta, mas deixarão de aparecer no app. Depois você terá que escolher onde salvar as novas.';

  @override
  String get stopUsingFolderDriveMessage =>
      'As gravações ficarão na pasta e o app passará a usar as do seu Google Drive, onde as novas serão salvas.';

  @override
  String get stopUsing => 'Deixar de usar';

  @override
  String get disconnectDriveStorageMessage =>
      'As gravações ficarão no seu Drive, mas deixarão de aparecer no app. Depois você terá que escolher onde salvar as novas.';

  @override
  String folderInUse(String folder) {
    return 'As gravações agora são salvas em “$folder”';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível salvar $count gravações',
      one: 'Não foi possível salvar 1 gravação',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => 'Não foi possível ler o Google Drive';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get syncNowSubtitle =>
      'Salva o que estiver pendente e procura mudanças onde as gravações são salvas';

  @override
  String get transcribe => 'Transcrever';

  @override
  String get viewTranscript => 'Ver transcrição';

  @override
  String transcribingProgress(String percent) {
    return 'Transcrevendo… $percent';
  }

  @override
  String get preparingTranscription => 'Preparando a transcrição…';

  @override
  String get waitingToTranscribe => 'Aguardando para transcrever…';

  @override
  String get cancelTranscription => 'Cancelar transcrição';

  @override
  String get transcriptReady => 'Transcrição pronta';

  @override
  String get view => 'Ver';

  @override
  String get transcriptionFailed => 'Não foi possível transcrever a gravação';

  @override
  String get noSpeechRecognized => 'Nenhuma palavra foi reconhecida';

  @override
  String get stopToTranscribe => 'Pare a gravação para transcrever';

  @override
  String get systemSpeechUnavailableTitle =>
      'O reconhecimento de voz não está disponível';

  @override
  String get systemSpeechUnavailableMessage =>
      'Este dispositivo não consegue transcrever com o reconhecimento de voz do sistema (no Android, é preciso a versão 13 ou superior). Você pode instalar o Whisper nas configurações.';

  @override
  String unsupportedLanguageMessage(String language) {
    return 'O reconhecimento de voz do sistema não suporta “$language” neste dispositivo. Você pode instalar o Whisper ou escolher outro idioma nas configurações.';
  }

  @override
  String get openSettings => 'Abrir configurações';

  @override
  String downloadLanguageTitle(String language) {
    return 'Baixar “$language”?';
  }

  @override
  String get downloadLanguageMessage =>
      'O reconhecimento de voz do sistema precisa baixar este idioma para transcrever no dispositivo. Tente novamente quando o download terminar.';

  @override
  String get download => 'Baixar';

  @override
  String get languageDownloading =>
      'O idioma ainda está sendo baixado. Tente novamente quando terminar.';

  @override
  String get speechPermission =>
      'Permita o reconhecimento de voz nas configurações para transcrever';

  @override
  String get whisperNotInstalledTitle => 'O Whisper não está instalado';

  @override
  String get whisperNotInstalledMessage =>
      'Para transcrever com o Whisper, baixe um modelo nas configurações.';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado para a área de transferência';

  @override
  String get transcribeAgain => 'Transcrever de novo';

  @override
  String get deleteTranscript => 'Excluir transcrição';

  @override
  String get transcriptDeleted => 'Transcrição excluída';

  @override
  String get transcriptOutdated => 'A gravação mudou desde que foi transcrita.';

  @override
  String get transcriptionSection => 'Transcrição';

  @override
  String get transcriptionEngine => 'Transcrever com';

  @override
  String get autoTranscribe => 'Transcrever automaticamente';

  @override
  String get autoTranscribeSubtitle =>
      'Em segundo plano, as gravações que ainda não têm transcrição';

  @override
  String get autoTranscriptionFailed =>
      'Não é possível transcrever as gravações automaticamente';

  @override
  String get systemSpeechRecognition => 'Reconhecimento de voz do sistema';

  @override
  String get systemSpeechDescription =>
      'Sem downloads. No Android, precisa da versão 13 ou superior';

  @override
  String get whisperDescription =>
      'No dispositivo, sem conexão. É preciso baixar um modelo';

  @override
  String get whisperModel => 'Modelo do Whisper';

  @override
  String get whisperNotInstalled => 'Não instalado. Toque para baixar um';

  @override
  String whisperInstalled(String model, String size) {
    return 'Instalado: $model ($size)';
  }

  @override
  String whisperDownloading(String model, String percent, String size) {
    return 'Baixando $model… $percent de $size';
  }

  @override
  String get whisperDownloadFailed => 'Não foi possível baixar o modelo';

  @override
  String get chooseWhisperModel => 'Baixar um modelo';

  @override
  String whisperTinyDescription(String size) {
    return '$size · Mais rápido, menos preciso';
  }

  @override
  String whisperBaseDescription(String size) {
    return '$size · Mais preciso, mais lento';
  }

  @override
  String get deleteWhisperModel => 'Excluir o modelo';

  @override
  String get deleteWhisperModelTitle => 'Excluir o modelo do Whisper?';

  @override
  String deleteWhisperModelMessage(String size) {
    return 'Isso libera $size. Você pode baixá-lo de novo depois.';
  }

  @override
  String get cancelDownload => 'Cancelar download';

  @override
  String get transcriptionLanguage => 'Idioma';

  @override
  String appLanguageOption(String language) {
    return 'O do app ($language)';
  }

  @override
  String get detectLanguageOption => 'Detectar automaticamente (só Whisper)';

  @override
  String get appearanceSection => 'Aparência';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Automático (o do sistema)';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';
}
