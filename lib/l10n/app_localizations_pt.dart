// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Gravador';

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
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gravações adicionadas da pasta',
      one: '1 gravação adicionada da pasta',
    );
    return '$_temp0';
  }

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
  String get savingCopies => 'Salvando cópias…';

  @override
  String get copiesFailed => 'Não foi possível salvar algumas cópias';

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
  String get importTitle => 'Adicionar as gravações da pasta?';

  @override
  String importMessage(String folder, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count áudios',
      one: '1 áudio',
    );
    return '“$folder” tem $_temp0 ($size) que não estão no app. Se você adicioná-los, eles aparecerão na lista e serão copiados para o app.';
  }

  @override
  String get add => 'Adicionar';

  @override
  String get dontAdd => 'Não adicionar';

  @override
  String get folderFailed => 'Não foi possível usar essa pasta';

  @override
  String get copiesKept => 'As cópias que já estão na pasta são mantidas';

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
  String get recordingSection => 'Gravação';

  @override
  String get formatNote =>
      'Aplica-se às novas gravações. Ao editar, cada gravação mantém seu formato.';

  @override
  String get storageSection => 'Onde as gravações são salvas';

  @override
  String get storageDescription =>
      'As gravações são sempre salvas dentro do app. Você também pode manter uma cópia de cada uma em uma pasta do dispositivo e no Google Drive, com o nome que você deu e na sua subpasta. As cópias são atualizadas ao renomear ou editar uma gravação, mas não são excluídas ao excluí-la.';

  @override
  String get deviceFolder => 'Pasta do dispositivo';

  @override
  String get noFolder => 'Não é salvo em nenhuma pasta';

  @override
  String get stopSavingToFolder => 'Parar de salvar na pasta';

  @override
  String get chooseAnotherFolder => 'Escolher outra pasta';

  @override
  String get showFolderRecordings => 'Mostrar as gravações da pasta';

  @override
  String get showFolderRecordingsSubtitle =>
      'Adiciona ao app os áudios (.m4a e .wav) da pasta e das suas subpastas';

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
  String get copyNow => 'Copiar agora';

  @override
  String get copyNowSubtitle => 'Só é copiado o que falta ou mudou';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível copiar $count gravações',
      one: 'Não foi possível copiar 1 gravação',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível adicionar $count gravações da pasta',
      one: 'Não foi possível adicionar 1 gravação da pasta',
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
}
