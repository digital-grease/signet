// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonAppTitle => 'SIGNET';

  @override
  String get commonOfflineFreeChip => '离线可用';

  @override
  String get commonCancel => '取消';

  @override
  String get commonCancelCaps => '取消';

  @override
  String get commonDone => '完成';

  @override
  String get commonGotIt => '知道了';

  @override
  String get commonBack => '返回';

  @override
  String get commonCopyPackage => '复制传输包';

  @override
  String get backupStep1Header => '第 1 步 // 保存传输包';

  @override
  String get backupStep1Body =>
      '把这个传输包保存到这部手机以外的地方，比如电脑或 U 盘，或者把二维码打印出来。手机丢失时，存在手机里的副本也会一起丢失。传输包不包含那 8 个单词，单独存在时无法恢复任何内容。';

  @override
  String get backupStep1BodyNoQr =>
      '把这个传输包保存到这部手机以外的地方，比如电脑或 U 盘。手机丢失时，存在手机里的副本也会一起丢失。传输包不包含那 8 个单词，单独存在时无法恢复任何内容。';

  @override
  String get backupSavePackageFile => '保存传输包文件（PACKAGE）';

  @override
  String get backupSavedAnotherWay => '我已用其他方式保存';

  @override
  String get backupStep2Header => '第 2 步 // 把 8 个单词放在别处';

  @override
  String get backupStep2Locked => '请先完成第 1 步。保存传输包后，这里会显示 8 个单词。';

  @override
  String get backupStep2Body =>
      '把这 8 个单词写在纸上，并写下下方的指纹，以便知道它们对应哪个传输包。把纸与传输包分开存放，例如放在钱包里。同时拥有两者的人可以恢复你的配对。';

  @override
  String get backupWroteOnPaper => '我已写在纸上';

  @override
  String get backupSaveWordsFile => '改为保存单词文件（WORDS）';

  @override
  String get backupWordsFileWarning =>
      '如果把单词保存为文件，请放在与传输包不同的地方：不要放在同一个文件夹、同一部手机或同一个云账号里。';

  @override
  String backupFingerprintLine(String fingerprint) {
    return '指纹：$fingerprint（传输包和单词显示同一个指纹）';
  }

  @override
  String get backupStepDone => '已完成';

  @override
  String get backupSavedBoth => '两者都已保存';

  @override
  String get backupShareFailed => '无法打开分享面板。请重试。';

  @override
  String get commonCopiedProtected =>
      '已复制。一分钟后，或你下次回到 Signet 时，Signet 会把它从剪贴板清除。';

  @override
  String get commonCopiedPlain => '已复制到剪贴板。';

  @override
  String get commonCopyFailed => '无法复制，请重试。';

  @override
  String backupPackageCopiedSnackbar(String copied) {
    return '$copied请现在把它粘贴到这部手机以外的地方，然后点“我已用其他方式保存”。';
  }

  @override
  String get commonStoreSeparatelyHeader => '分开存放 //';

  @override
  String get commonRememberHeader => '切记 //';

  @override
  String get commonPakeSecretHeader => 'PAKE 密语 //';

  @override
  String get commonPairTimePhraseHeader => '配对短语 //';

  @override
  String get commonNameThisContactHeader => '为联系人命名 //';

  @override
  String get commonNameHintExample => '例如：Alice';

  @override
  String get labelRejectEmpty => '请输入联系人名称。';

  @override
  String get labelRejectData => '这看起来像 Signet 数据，不像名字。试试“妈妈”这样的名称。';

  @override
  String get labelRejectKey => '这看起来像密钥，不像名字。试试“妈妈”这样的名称。';

  @override
  String get labelRejectTooLong => '名称太长了，请换一个短一点的。';

  @override
  String get labelRestoredFallback => '已恢复的联系人';

  @override
  String get labelRestoredSuffix => '（已恢复）';

  @override
  String get scannerCameraErrorTitle => '相机没有启动';

  @override
  String get scannerCameraErrorBody => '请关闭正在使用相机的其他应用，然后重试。';

  @override
  String get scannerCameraErrorBodyPaste => '请关闭正在使用相机的其他应用，然后重试，或者改为粘贴文本。';

  @override
  String get scannerRetry => '重试';

  @override
  String get scannerUsePaste => '改为粘贴';

  @override
  String get scannerNotSignetPackage => '这个二维码不是 Signet 传输包。请扫描备份中的二维码。';

  @override
  String get scannerTitle => '扫描二维码';

  @override
  String get backupImportScanQr => '扫描二维码';

  @override
  String backupImportReplacedLabelNotice(String label) {
    return '备份中保存的名称无法使用，因此该联系人将以“$label”恢复。恢复后可以改名。';
  }

  @override
  String labelLengthCounter(int used, int max) {
    return '$used / $max';
  }

  @override
  String get pairTransportOutYourNameHeader => '你的名字（对方看到的）//';

  @override
  String get pairTransportOutYourNameDescription =>
      '可选。对方手机会把它建议为你的名字，对方可以修改。中文等文字每个字占用更多空间，请尽量简短。';

  @override
  String get pairTransportOutOwnPackageError => '这是你自己创建的传输包。请粘贴对方发回的那个。';

  @override
  String get commonPasteFromClipboard => '从剪贴板粘贴';

  @override
  String get commonUnlocking => '解锁中…';

  @override
  String get commonSaving => '保存中…';

  @override
  String get commonGenerating => '生成中…';

  @override
  String get commonCommitPair => '完成配对';

  @override
  String get commonConfirmPairingTitle => '确认配对';

  @override
  String commonUnlockFailedError(String error) {
    return '无法解锁：$error';
  }

  @override
  String commonSaveFailedError(String error) {
    return '无法保存：$error';
  }

  @override
  String get pairConfirmSaveIncompleteError =>
      'Signet 未能完成保存此配对。请关闭 Signet 后重新打开。如果联系人出现在列表中，说明已保存；如果没有，请一起重新配对。';

  @override
  String get pairConfirmRekeySaveIncompleteError =>
      '轮换密钥未完成。在依靠 Signet 验证此联系人之前，请在两部手机上重新进行轮换密钥。';

  @override
  String get commonGiveContactName => '请为这个联系人起个名字。';

  @override
  String get commonRelationshipNotFound => '未找到该配对联系人。';

  @override
  String get commonAirplaneFooter => '离线可用。Signet 从不连接互联网。';

  @override
  String get homeHelpTooltip => '帮助';

  @override
  String get homeMoreTooltip => '更多';

  @override
  String get homeMenuFaq => 'FAQ';

  @override
  String get homeMenuContactUs => '联系我们';

  @override
  String get homeMenuSettings => '设置';

  @override
  String get homeMenuShowIntro => '重新查看引导';

  @override
  String get homeMenuAbout => '关于';

  @override
  String homeErrorLoadFailed(String error) {
    return '无法读取配对联系人。\n$error';
  }

  @override
  String get homeTryAgainButton => '重试';

  @override
  String get homeFabPair => '配对';

  @override
  String get homeEmptyTitle => '还没有配对。';

  @override
  String get homeEmptyBody => '与你信任的人当面配对。之后在任何通话中都可以互相验证。';

  @override
  String get homeEmptyPairContactButton => '配对联系人';

  @override
  String get homeEmptySendPackageButton => '发送传输包';

  @override
  String get homeEmptyHavePackageButton => '我有传输包';

  @override
  String get homeEmptyRestoreBackupButton => '从备份恢复';

  @override
  String get homeRenameDialogTitle => '重命名联系人';

  @override
  String get homeRenameFieldLabel => '联系人名称';

  @override
  String get homeRenameEmptyError => '名称不能为空。';

  @override
  String get homeSaveButton => '保存';

  @override
  String homeUnpairDialogTitle(String label) {
    return '解除与 $label 的配对？';
  }

  @override
  String get homeUnpairDialogBody => '这会删除本机上的共享密钥。之后要再验证，只能从头重新配对。';

  @override
  String get homeUnpairConfirmButton => '解除配对';

  @override
  String homeUnpairSnackbar(String label) {
    return '已解除与 $label 的配对。';
  }

  @override
  String get homeUndoAction => '撤销';

  @override
  String get homePairMenuInPerson => '当面配对';

  @override
  String get homePairMenuInPersonSubtitle => '两部手机放在一起，互相扫码';

  @override
  String get homePairMenuSendPackage => '发送传输包';

  @override
  String get homePairMenuSendPackageSubtitle => '通过可信渠道与远方的人配对';

  @override
  String get homePairMenuHavePackage => '我有传输包';

  @override
  String get homePairMenuHavePackageSubtitle => '导入别人发来的传输包';

  @override
  String get homePairMenuRestoreBackup => '从备份恢复';

  @override
  String get homePairMenuRestoreBackupSubtitle => '从纸质备份恢复配对联系人';

  @override
  String homeRowMenuRename(String label) {
    return '重命名 $label';
  }

  @override
  String get homeRowMenuHapticsOn => '开启触感反馈';

  @override
  String get homeRowMenuHapticsOff => '关闭触感反馈';

  @override
  String get homeRowMenuShowBinding => '查看绑定短语';

  @override
  String get homeRowMenuVerifyVideo => '验证（视频通话）';

  @override
  String get homeRowMenuVerifyVideoSubtitle => '额外检查一个肢体动作，可抵御深度伪造';

  @override
  String get homeRowMenuCrGrid => '挑战-应答网格';

  @override
  String get homeRowMenuCrGridSubtitle => '对方没有手机时的备用方案';

  @override
  String homeRowMenuRekey(String label) {
    return '轮换 $label 的密钥';
  }

  @override
  String get homeRowMenuRekeySubtitle => '当面轮换共享密钥';

  @override
  String get homeRowMenuBackupPaper => '备份到纸上';

  @override
  String get homeRowMenuBackupPaperSubtitle => '换新手机时可用它恢复';

  @override
  String homeRowMenuUnpair(String label) {
    return '解除与 $label 的配对';
  }

  @override
  String get homeDebugBannerSemantics => '调试日志已开启。双击前往设置管理。';

  @override
  String get homeDebugBannerText => '调试日志已开启 — 正在记录应用活动';

  @override
  String get homeSectionRelationships => '配对关系 //';

  @override
  String homeRowMetadata(String role, String fingerprint, String date) {
    return '角色:$role · $fingerprint · $date';
  }

  @override
  String get homeHapticsOffChip => '触感 // 关';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutSectionSignet => 'SIGNET';

  @override
  String get aboutIntroBody =>
      '面向人际关系的密码学多因素认证。通过设备对设备的轮换码，防御语音与视频深度伪造诈骗。零服务器，离线优先。';

  @override
  String aboutVersionLabel(String version) {
    return '版本：$version';
  }

  @override
  String get aboutSectionLicense => '许可证';

  @override
  String get aboutLicenseBody =>
      'AGPL-3.0-only。Signet 是自由软件，你可以依据 GNU Affero 通用公共许可证第 3 版的条款使用、修改和再分发它。';

  @override
  String get aboutSectionSource => '源代码';

  @override
  String get aboutSourceBody => '源代码、issue 跟踪与发布产物托管在 GitHub。';

  @override
  String get aboutOpenRepositoryButton => '打开仓库';

  @override
  String get aboutSectionPrivacy => '隐私';

  @override
  String get aboutPrivacyBody => 'Signet 不收集任何数据，也不发送任何数据。没有服务器，没有账号，没有遥测。';

  @override
  String get aboutPrivacyPolicyButton => '隐私政策';

  @override
  String get aboutSectionReportBug => '报告问题';

  @override
  String get aboutReportBugBody => '发现了问题？请在 GitHub 提交 issue，注明设备、系统版本和触发步骤。';

  @override
  String get aboutOpenIssuesButton => '打开 issue 列表';

  @override
  String get aboutSectionSupport => '支持项目';

  @override
  String get aboutSupportBody =>
      '如果 Signet 对你有用，欢迎请我喝杯咖啡。Signet 由一人维护，应用内没有任何付费档位或增值推销。支持完全自愿，非常感谢。';

  @override
  String get aboutBuyMeCoffeeButton => '请我喝咖啡';

  @override
  String get aboutCopyright => '© digital-grease';

  @override
  String get crashReportTitle => 'Signet 遇到了问题';

  @override
  String get crashReportIntroBody => '应用在上次运行时崩溃了。发送报告有助于我们修复问题。';

  @override
  String get crashReportContainsHeading => '报告内容包括：';

  @override
  String get crashReportBulletDevice => '你的设备 + 系统 + 应用版本';

  @override
  String get crashReportBulletStack =>
      '一份堆栈跟踪，其中所有密码学材料（配对密钥、验证码、备份数据）都会在离开你的手机前替换为 [redacted:N] 标记。';

  @override
  String get crashReportChooseHeading => '选择发送方式：';

  @override
  String get crashReportDismissButton => '关闭';

  @override
  String get crashReportCopyLogButton => '复制日志';

  @override
  String get crashReportFileIssueButton => '提交 issue';

  @override
  String get crashReportCopiedSnackbar => '崩溃日志已复制到剪贴板。';

  @override
  String get crashReportOpenFailedSnackbar => '无法打开浏览器。崩溃日志已复制到剪贴板，你可以手动粘贴。';

  @override
  String get crashReportTruncatedSnackbar =>
      '跟踪内容较长 — 完整日志已复制到剪贴板。请把它粘贴到 GitHub 上截断标记的下方。';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqQ1 => 'Signet 到底是做什么的？';

  @override
  String get faqA1 =>
      'Signet 让你确认来电、短信或视频那头的人确实是本人 — 即使对方声音很像、知道你的个人情况、而且在催你办急事。你只需与信任的人当面配对一次。此后任何一方都可以索要一个 4 单词口令，只有真正的配对设备才能生成它。';

  @override
  String get faqQ2 => '“验证通过”究竟证明了什么？';

  @override
  String get faqA2 =>
      '它证明对方能接触到与你配对的那部手机，且那部手机未被攻破。它不证明对方的声音是真的 — 如果一个深度伪造既能合成声音，又能胁迫真机前的人念出口令，仍然会通过验证。Signet 的目标是把攻击者的成本从“克隆声音”抬高到“还得偷到一部已解锁的真机”。';

  @override
  String get faqQ3 => '4 单词口令为什么一直在变？';

  @override
  String get faqA3 =>
      '每个口令只在 30 秒内有效。这样即使攻击者在一次真实通话中录下了口令，之后也无法重放。Signet 接受当前窗口以及前后各一个窗口的口令，所以时钟稍有偏差或念得慢一点也不会导致正常验证失败。';

  @override
  String get faqQ4 => '如果口令对不上怎么办？';

  @override
  String get faqA4 =>
      '把它当作危险信号。真实配对联系人的口令几乎总能一次对上。对不上就挂断，通过你独立掌握的其他渠道（已知手机号、当面、共同朋友）联系本人，确认无误后再处理对方提出的任何请求。';

  @override
  String get faqQ5 => 'Signet 能看到我的配对或口令吗？';

  @override
  String get faqA5 =>
      '不能。Signet 没有服务器、没有账号、没有遥测、没有统计分析，在 Android 上也不申请联网权限。你们的共享密钥保存在手机的安全硬件（Keychain/Keystore）中，不会离开设备。即使 Signet 明天消失，你的数据也不会跟着消失。';

  @override
  String get faqQ6 => '手机丢了怎么办？';

  @override
  String get faqA6 =>
      '如果丢失前做过备份，可以用“从备份恢复”把配对联系人恢复到新手机。对方什么都不用做，甚至不会察觉发生过恢复。如果没有备份，配对就丢失了，需要在新设备上与该联系人当面重新配对。';

  @override
  String get faqQ12 => '怎样安全地保存备份？';

  @override
  String get faqA12 =>
      '备份分两部分：传输包文件（PACKAGE，已加密）和用来解锁它的 8 个单词。两者要分开存放。把传输包文件存到手机以外的地方，比如电脑或 U 盘。把 8 个单词写在纸上，放在别处，比如钱包里。同时拿到两部分的人就能向你的联系人冒充你，所以不要把它们放在一起，也不要用消息发送这些单词。恢复时，点“从备份恢复”，载入传输包文件，再输入 8 个单词。';

  @override
  String get faqQ7 => '可以和多个人配对吗？';

  @override
  String get faqA7 => '可以。想配多少个都行 — 每次配对相互独立。每段关系有自己的密钥，一处配对被攻破不会泄露或影响其他配对。';

  @override
  String get faqQ8 => '挑战-应答网格是什么？';

  @override
  String get faqA8 =>
      '一种离线备用方案，用于对方无法使用手机的情况。你们双方各有一张由共享密钥推导出的相同 8x8 单词网格。你问“orange-anchor 对应的短语是什么？” — 对方查表（在应用里或打印的卡片上）并念出三个单词的答案。与你的应用一致，就说明配对是真实的。';

  @override
  String get faqQ9 => '视频通话验证为什么要求做肢体动作？';

  @override
  String get faqA9 =>
      'AI 语音和视频深度伪造越来越强。能听到你索要 4 个单词的实时深度伪造可以直接复述 — 但普通验证之所以有效，正是因为这些单词只能来自配对设备。然而，能听到你念出“摸摸耳朵”这类随机指令的深度伪造，也能立刻模仿这个动作。所以 Signet 把动作也变成由共享密钥推导的内容：只有真正的配对设备知道这个窗口内应该做哪个动作。开启视频通话模式后，通过验证需要同时满足：4 个单词正确，且对方做出了预期动作。没有配对设备的深度伪造只能靠猜，合计成功率在每 30 秒窗口内约为 100 万亿分之一。如果你使用读屏软件，通话时请戴耳机：Signet 不会自动朗读这个动作，但轻触“注意观察”这一行会读出它，开着扬声器时对方可能听到。';

  @override
  String get faqQ10 => '为什么没有账号？需要恢复怎么办？';

  @override
  String get faqA10 =>
      '账号意味着服务器、密码，以及攻击者（或传票）可以绕过你的手机触达配对数据的通路。Signet 的存在正是因为其他认证工具都有这样的通路。恢复是手动的：趁现在一切正常，做一份备份，放在手机丢失时你能拿到的地方。';

  @override
  String get faqQ11 => '有人要求我跳过验证步骤。';

  @override
  String get faqA11 =>
      '不要跳过。真实的配对联系人明白验证存在的意义，不会施压让你绕过它。制造紧迫感并要求跳过验证，正是骗子瓦解安全防线的惯用手法。如果你正被施压，在证明清白之前，默认这通电话是恶意的。';

  @override
  String get faqQ13 => 'Signet 提示需要更新。';

  @override
  String get faqA13 =>
      'Signet 有时会改变配对码和备份的生成方式，旧版本无法读取新的格式。\n\n如果配对码或备份来自较新版本的 Signet，它会提示这部手机需要更新。配对时，如果对方手机的版本较旧，它会提示对方手机需要更新。配对需要两部手机都使用 Signet 0.4.0 或更高版本。备份可以在相同或更新版本的 Signet 上恢复。\n\n只通过你安装 Signet 的应用商店更新。Signet 从不通过链接或文件发送更新。如果有人给你发来更新，或催你安装某个东西才能完成配对，那就是诈骗。\n\nSignet 0.3.6 及更早版本无法显示这条提示，而是会说这不是 Signet 的配对码。';

  @override
  String get faqStillStuckHeader => '仍未解决 //';

  @override
  String get faqStillStuckBody =>
      '在这里没找到答案？请在 GitHub 提交 issue，注明你的设备、系统版本以及你想做什么。';

  @override
  String get faqContactUsButton => '联系我们';

  @override
  String get onboardingSkipButton => '跳过';

  @override
  String get onboardingBriefingTag1 => '简报 // 01';

  @override
  String get onboardingBriefingTag2 => '简报 // 02';

  @override
  String get onboardingBriefingTag3 => '简报 // 03';

  @override
  String get onboardingSlide1Title => '验证电话那头是谁。';

  @override
  String get onboardingSlide1Body =>
      '深度伪造的语音和视频可以冒充任何人 — 家人、同事、消息源。当有人带着紧迫感来电，要钱、要帮助、要权限时，Signet 让你可以索要一段轮换的 4 单词短语，只有对方真正的手机才能生成。对得上，你就能确认。';

  @override
  String get onboardingSlide2Title => '当面配对一次。';

  @override
  String get onboardingSlide2Body =>
      '见面时互相扫描对方的二维码，即可完成两部手机的配对。共享密钥只保存在两台设备上 — 硬件保护、离线、无云端。没有被传唤的余地，没有被钓鱼的余地，也不存在要同步到的服务器。';

  @override
  String get onboardingSlide3Title => '索要短语。';

  @override
  String get onboardingSlide3Body =>
      '通话时打开 Signet，点开联系人，请对方念出他们的 4 个单词。把听到的输入进去。绿色横幅 = 验证通过，可以信任这通电话。红色横幅 = 不要信任。挂断，改用你已知的号码回拨。';

  @override
  String get onboardingContinueButton => '继续';

  @override
  String get pairStartTitle => '配对联系人';

  @override
  String get pairStartHeading => '这个人叫什么名字？';

  @override
  String get pairStartPrivacyNote => '只保存在你的手机上。用一眼能认出的名字 — “妈妈”、“小张”、“财务部”。';

  @override
  String get pairStartNameLabel => '名称';

  @override
  String get pairStartEmptyNameError => '请为这个联系人输入名称。';

  @override
  String get pairStartContinueButton => '继续';

  @override
  String pairExchangeTitlePair(String contact) {
    return '与 $contact 配对';
  }

  @override
  String pairExchangeTitleRekey(String contact) {
    return '与 $contact 轮换密钥';
  }

  @override
  String get pairExchangeFallbackContact => '联系人';

  @override
  String get pairInPersonIntro =>
      '请在同一个房间里，把两部手机放在一起。只扫描对方手机本身，绝不要扫描照片或视频通话里的码：那些码可能被调包。';

  @override
  String get pairInPersonRoleHint => '先说好谁先开始。那部手机点“发起”，另一部手机点“加入”。';

  @override
  String get pairInPersonNextButton => '下一步';

  @override
  String get pairInPersonNextHint => '等对方手机显示出它自己的码后再点。';

  @override
  String get pairInPersonShowWordsButton => '显示单词';

  @override
  String get pairInPersonFinishHint => '等对方手机显示出 4 个单词后再点。';

  @override
  String get pairInPersonShowAgainButton => '再次显示我的码';

  @override
  String get pairInPersonQrLabel => '配对二维码';

  @override
  String get pairCodeAlreadyScannedNotice => '已经扫描过了。请等对方手机显示下一个码。';

  @override
  String get pairInPersonPasteFromClipboard => '从剪贴板粘贴';

  @override
  String pairInPersonCopiedSnackbar(String status) {
    return '$status请你自己把它交给对方手机，然后当面一起核对 4 个单词。';
  }

  @override
  String get pairInPersonStartButton => '发起';

  @override
  String get pairInPersonStartSubtitle => '这部手机先显示它的码。';

  @override
  String get pairInPersonJoinButton => '加入';

  @override
  String get pairInPersonJoinSubtitle => '这部手机先扫描对方的手机。';

  @override
  String pairInPersonStepLabel(int step) {
    return '第 $step 步，共 3 步';
  }

  @override
  String get pairInPersonShowHeading => '让对方手机扫描这个码。';

  @override
  String get pairInPersonShowRevealHeading => '让对方手机也扫描这个码。';

  @override
  String get pairInPersonScanHeading => '扫描对方的手机。';

  @override
  String get pairInPersonScanRevealHeading => '再扫描一次对方的手机。';

  @override
  String get pairInPersonPreparing => '正在准备…';

  @override
  String get pairInPersonDeriving => '正在计算单词…';

  @override
  String get pairInPersonJoinIdleHint =>
      '还没有扫描到。对方手机是否点了“发起”并显示出码？如果两部手机都点了“加入”，请在两部手机上都点“重新开始”，然后让其中一部点“发起”。';

  @override
  String get pairInPersonStartIdleHint =>
      '还没有扫描到。对方手机是否点了“加入”并显示出码？如果两部手机都点了“发起”，请在两部手机上都点“重新开始”，然后让其中一部点“加入”。';

  @override
  String get pairInPersonShowAsText => '以文字显示这个码';

  @override
  String get pairInPersonShowAsQr => '显示二维码';

  @override
  String get pairInPersonCopyCode => '复制配对码';

  @override
  String get pairInPersonPasteInstead => '改为粘贴配对码';

  @override
  String get pairInPersonPasteHeading => '粘贴对方手机的码';

  @override
  String get pairInPersonPasteLabel => '配对码';

  @override
  String get pairInPersonPasteSubmit => '使用这个码';

  @override
  String get pairInPersonPasteEmptyError => '请先粘贴对方手机的码。';

  @override
  String get pairInPersonBackToCamera => '返回相机';

  @override
  String get pairInPersonStartOverButton => '重新开始';

  @override
  String get pairInPersonStartOverBoth =>
      '在两部手机上都点“重新开始”；如果某部手机已经显示单词，就在那部手机上点“不一致”。然后一部手机点“发起”，另一部点“加入”。';

  @override
  String get pairCodeMalformedNotice => '这个码不完整或已损坏。请重新扫描或粘贴。';

  @override
  String get pairCodeNotPairingNotice => '这不是 Signet 的配对码。请扫描对方手机配对界面上的码。';

  @override
  String get pairCodeMultipleNotice => '一次只粘贴一个码。';

  @override
  String get pairCodePeerNeedsUpdateNotice =>
      '对方手机上的 Signet 版本较旧，需要先更新才能配对。请只通过当初安装 Signet 的应用商店更新。Signet 从不通过链接或文件发送更新。';

  @override
  String get pairCodeThisNeedsUpdateNotice =>
      '这个码来自较新版本的 Signet。请先在这部手机上更新 Signet，只通过你安装它的应用商店更新。Signet 从不通过链接或文件发送更新。';

  @override
  String get pairFailStartStart => '这部手机扫描到的是“发起”的码。必须一部手机点“发起”，另一部点“加入”。';

  @override
  String get pairFailJoinJoin => '这部手机扫描到的是“加入”的码。必须一部手机点“发起”，另一部点“加入”。';

  @override
  String get pairFailSecondCode => '中途扫描到另一个不同的码，为了安全，这次配对已结束。';

  @override
  String get pairFailWrongCode => '这个码属于另一个步骤，为了安全，这次配对已结束。';

  @override
  String get pairFailRevealMismatch =>
      '停止。最后一个码与第一个码不符，可能有人在干扰。如果对方手机显示了单词，请在那部手机上点“不一致”。不要保存这次配对。';

  @override
  String get pairFailTimedOut => '时间过长，这次配对已结束。';

  @override
  String get pairFailInternal => '这部手机出了问题。';

  @override
  String get pairExchangeCameraPermissionTitle => '相机权限已关闭。';

  @override
  String pairExchangeCameraPermissionBody(String path) {
    return 'Signet 只在扫描配对二维码时需要相机。请在手机设置中开启：$path。';
  }

  @override
  String get pairCameraSettingsPathIos => '设置 → Signet → 相机';

  @override
  String get pairCameraSettingsPathAndroid => '应用 → Signet → 权限 → 相机';

  @override
  String get pairConfirmTitle => '确认';

  @override
  String get pairConfirmRekeyTitle => '确认轮换密钥';

  @override
  String get pairConfirmHeading => '和对方屏幕上的一致吗？';

  @override
  String get pairConfirmInstructions => '大声念出来。两台设备上的四个单词应完全一致。';

  @override
  String get pairConfirmMatchButton => '一致';

  @override
  String get pairConfirmMismatchButton => '不一致 — 重新开始';

  @override
  String get pairConfirmMismatchDialogTitle => '短语不一致？';

  @override
  String get pairConfirmMismatchDialogBody =>
      '如果你的短语和对方的不一致，说明出了问题 — 可能是扫码失败，也可能是有人试图中间人介入。更安全的做法是放弃这次配对，重新开始。';

  @override
  String get pairConfirmStartOverButton => '重新开始';

  @override
  String pairConfirmRekeySnackbar(String label) {
    return '已与 $label 轮换配对密钥。';
  }

  @override
  String pairConfirmPairedSnackbar(String label) {
    return '已与 $label 配对。';
  }

  @override
  String get pairConfirmStateIncompleteError => '配对状态不完整。';

  @override
  String get pairConfirmRekeyTargetMissingError => '要轮换的配对关系已不存在。';

  @override
  String get pairCompleteTitle => '配对完成';

  @override
  String get pairCompleteCommittedHeader => '配对已保存 //';

  @override
  String get pairCompleteHeading => '你们俩都还站在这里。\n现在就试一次验证。';

  @override
  String pairCompletePracticeBody(String label) {
    return '现在练习验证最容易。请 $label 打开 Signet，点你的名字，念出“显示我的 4 个单词”界面上的 4 个单词。把你听到的输入到验证输入框。绿色横幅出现时，你就知道它是真实可用的。';
  }

  @override
  String get pairCompleteRemoteHeading => '已远程配对。\n下次通话时练习一次。';

  @override
  String pairCompleteRemoteBody(String label) {
    return '下次和 $label 说话时，请对方打开 Signet，点你的名字，念出“显示我的 4 个单词”界面上的 4 个单词。把你听到的输入到验证输入框。绿色横幅出现时，你就知道它是真实可用的。';
  }

  @override
  String pairCompleteRemoteWaitNote(String label) {
    return '$label 粘贴你的响应包之后，验证才会生效。';
  }

  @override
  String get pairCompleteFallbackPeer => '对方';

  @override
  String get pairCompleteTipBody => '跳过也没关系，之后随时可以从主页验证。但成本最低的练习机会就是现在。';

  @override
  String pairCompleteVerifyNowButton(String label) {
    return '立即验证 $label';
  }

  @override
  String get pairCompleteSkipButton => '跳过 — 以后再说';

  @override
  String get pairTransportInImportTitle => '导入传输包';

  @override
  String get pairTransportInIncomingHeader => '收到的传输包 //';

  @override
  String get pairTransportInPasteInstruction => '粘贴发件人给你的文本。以“signet:tp1:”开头。';

  @override
  String get pairTransportInPakeDescription =>
      '这 8 个单词是发件人通过可信渠道（纸质、加密邮件、事先见面的约定）告诉你的。不要通过未经验证的语音电话接受这些单词。';

  @override
  String get pairTransportInUnlockButton => '解锁传输包';

  @override
  String get pairTransportInPasteEmptyError => '请粘贴发件人给你的传输包。';

  @override
  String get pairTransportInWordsIncompleteError => '请输入发件人给的全部 8 个单词。';

  @override
  String pairTransportInProcessFailedError(String error) {
    return '处理传输包失败：$error';
  }

  @override
  String get pairTransportInPhraseInstruction =>
      '逐个、按顺序核对全部 8 个单词，并确认两部手机都正好显示 8 个。请与发件人当面核对，或拨打你原本就有的对方号码核对。不要通过消息核对，也绝不要使用别人给你的电话或号码。如果全部一致，这个传输包就是真实的。';

  @override
  String get pairTransportInResponseHeader => '你的响应包 //';

  @override
  String get pairTransportInResponseInstruction =>
      '用接收对方传输包的同一条渠道把它发回给发件人。对方粘贴后即可完成配对。';

  @override
  String get pairTransportInCopyResponseButton => '复制响应包';

  @override
  String get pairTransportOutNewPackageTitle => '新建传输包';

  @override
  String get pairTransportOutShareWaitTitle => '分享并等待';

  @override
  String get pairTransportOutNameDescription => '这是配对后在你主页上显示的联系人名称，只有你能看到。';

  @override
  String get pairTransportOutGenerateButton => '生成传输包';

  @override
  String pairTransportOutGenerateError(String error) {
    return '无法生成传输包：$error';
  }

  @override
  String get pairTransportOutOutgoingHeader => '发出的传输包 //';

  @override
  String pairTransportOutOutgoingInstruction(String label) {
    return '把这段文本发给 $label。加密邮件、Signal、纸质信使、打印的二维码 — 任何渠道都可以。但只有同时拥有下面 8 个 PAKE 单词的人才能使用它。';
  }

  @override
  String get pairTransportOutChannelWarning =>
      '这 8 个单词务必通过与传输包不同的渠道发送。绝不要使用别人提供的电话或号码。纸质、事先见面的约定，或另一段已配对的 Signet 关系，都比口头念出来更安全。';

  @override
  String get pairTransportOutReceiveHeader => '接收响应包 //';

  @override
  String pairTransportOutReceiveInstruction(String label) {
    return '$label 会给你发来响应包。把它粘贴到这里。';
  }

  @override
  String get pairTransportOutPasteEmptyError => '请粘贴接收方发来的响应包。';

  @override
  String get pairTransportOutUnlockResponseButton => '解锁响应包';

  @override
  String pairTransportOutUnlockFailedError(String error) {
    return '无法解锁响应包：$error';
  }

  @override
  String get pairingWeakKeyInPersonError =>
      '停止。这个配对码不安全。请在两部手机上都取消配对，然后重新开始。不要相信任何一部手机上显示的单词。';

  @override
  String get pairingWeakKeyRemoteError =>
      '这个配对包不安全，可能已被篡改。请关闭此页面，重新生成配对包，并换一种与之前不同的方式发送。不要相信任何一部手机上显示的单词。';

  @override
  String pairTransportOutPhraseInstruction(String label) {
    return '逐个、按顺序核对全部 8 个单词，并确认两部手机都正好显示 8 个。请与 $label 当面核对，或拨打你原本就有的对方号码核对。不要通过消息核对，也绝不要使用别人给你的电话或号码。如果全部一致，配对就是真实的。';
  }

  @override
  String get backupExportTitle => '备份到纸上';

  @override
  String backupExportGenerateError(String error) {
    return '无法生成备份：$error';
  }

  @override
  String backupExportHeading(String label) {
    return '备份 $label';
  }

  @override
  String backupExportIntro(String label) {
    return '有了备份，手机丢失后就能在新手机上恢复这段配对。$label 的手机不会察觉任何变化。';
  }

  @override
  String get backupExportStoreSeparatelyBody =>
      '这份备份分两部分：传输包，以及解锁它的 8 个单词。请分开存放。如果有人同时拿到两者，就能在自己的手机上恢复这段配对。';

  @override
  String backupExportRememberBody(String label) {
    return '如果有别人同时拿到了传输包和这 8 个单词，请立即解除与 $label 的配对并当面重新配对。备份里包含与当前配对相同的密钥。';
  }

  @override
  String get backupImportRestoreTitle => '恢复备份';

  @override
  String get backupImportConfirmTitle => '确认导入';

  @override
  String get backupImportFileTooLargeError =>
      '这个文件太大，不可能是 Signet 备份。请选择你创建备份时保存的那个小文本文件。';

  @override
  String get backupImportFileReadError => '无法读取所选文件。请重新选择。';

  @override
  String get backupImportPasteEmptyError => '请先载入或粘贴你的备份传输包。';

  @override
  String get backupImportWordsIncompleteError => '请输入全部 8 个备份单词。';

  @override
  String get backupImportPackageHeader => '第 1 步 // 传输包';

  @override
  String get backupImportLoadPackageFile => '载入传输包文件（PACKAGE）';

  @override
  String get backupImportWordsHeader => '第 2 步 // 8 个单词';

  @override
  String get backupImportLoadWordsFile => '载入单词文件（WORDS）';

  @override
  String get backupImportIsWordsError => '这是 8 个单词，不是传输包。请放在第 2 步。';

  @override
  String get backupImportIsPackageError => '这是传输包，不是单词。请放在第 1 步。';

  @override
  String get backupImportNoWordsError => '那里没有找到备份单词。请找一行 8 个单词。';

  @override
  String backupImportFingerprintMismatchError(String package, String words) {
    return '这些单词属于另一个备份（传输包 $package，单词 $words）。请找指纹为 $package 的单词。';
  }

  @override
  String get backupImportLegacyNotice =>
      '这是旧版备份，单词和传输包保存在同一个文件里。恢复后，请重新备份并删除此文件。';

  @override
  String get backupImportNotBackupError => '不是有效的 Signet 备份。';

  @override
  String get backupImportInvitationError => '这是配对邀请，不是备份。请从主页使用配对流程。';

  @override
  String get backupImportClipboardEmptyError => '剪贴板是空的。';

  @override
  String get backupImportPasteInstruction =>
      '载入传输包文件（PACKAGE），或粘贴传输包文本。它以“signet:tp1:”开头。';

  @override
  String get backupImportWordsInstruction => '输入你记下的 8 个单词，或载入你保存的单词文件（WORDS）。';

  @override
  String get backupImportUnlockButton => '解锁备份';

  @override
  String get backupImportRestoredPeerHeader => '恢复的联系人 //';

  @override
  String get backupImportRoleLabel => '角色 //';

  @override
  String get backupImportOriginallyLabel => '原配对时间 //';

  @override
  String get backupImportHapticsLabel => '触感 //';

  @override
  String get backupImportHapticsOff => '关';

  @override
  String get backupImportHapticsOn => '开';

  @override
  String get backupImportWhatItDoesHeader => '这会做什么 //';

  @override
  String backupImportWhatItDoesBody(String label) {
    return '这部手机将与 $label 使用与旧手机相同的密钥材料共享密钥。$label 的手机不会察觉任何变化。如果备份之后对方已与其他人轮换过密钥，验证会失败，直到你当面重新配对。';
  }

  @override
  String get backupImportCommitButton => '确认导入';

  @override
  String get bulkBackupExportSetupTitle => '全部备份';

  @override
  String get bulkBackupExportReadyTitle => '批量备份已生成';

  @override
  String bulkBackupExportPrepareError(String error) {
    return '无法准备备份：$error';
  }

  @override
  String get bulkBackupExportNoSecretsError => '没有任何配对关系的密钥可读取。';

  @override
  String get bulkBackupExportEmptyTitle => '还没有可备份的内容。';

  @override
  String get bulkBackupExportEmptyBody => '请先与别人配对，再回到这里创建批量备份。';

  @override
  String bulkBackupExportReadyHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个配对关系',
      one: '1 个配对关系',
    );
    return '备份 $_temp0';
  }

  @override
  String get bulkBackupExportReadyBody =>
      '下面所有配对联系人会放进同一份备份：一个传输包，以及解锁它的 8 个单词。两者分开存放，之后用它们把所有配对迁移到新手机。';

  @override
  String get bulkBackupExportGenerateButton => '生成批量备份';

  @override
  String bulkBackupExportDoneHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已备份 $count 个配对关系',
      one: '已备份 1 个配对关系',
    );
    return '$_temp0';
  }

  @override
  String get bulkBackupExportStoreSeparatelyBody =>
      '这份备份分两部分：传输包，以及解锁它的 8 个单词。请分开存放。如果有人同时拿到两者，就能在自己的手机上恢复所有配对。';

  @override
  String get bulkBackupExportWordsInstruction =>
      '把这 8 个单词写到安全的地方。在新手机上输入它们即可一次性解锁全部内容。';

  @override
  String get bulkBackupExportPackageInstruction =>
      '全部配对的集合，用上面的 8 个单词加密。可通过任何渠道分享 — 单词是它的封印。';

  @override
  String bulkBackupExportShareSubject(int count) {
    return 'Signet 批量备份 - $count 位联系人';
  }

  @override
  String get bulkBackupExportRememberBody =>
      '如果有别人同时拿到了传输包和这 8 个单词，请解除其中所有联系人的配对并当面重新配对。备份里包含与你当前配对相同的密钥。';

  @override
  String get bulkBackupImportTitle => '批量恢复';

  @override
  String get bulkBackupImportDoneTitle => '已恢复';

  @override
  String bulkBackupImportGenericError(String error) {
    return '错误：$error';
  }

  @override
  String bulkBackupImportPreviewHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个配对关系',
      one: '1 个配对关系',
    );
    return '恢复 $_temp0';
  }

  @override
  String get packageNeedsNewerSignetError =>
      '需要较新版本的 Signet。请只通过你最初安装 Signet 的应用商店更新。Signet 从不通过链接或文件发送更新。如果你没有预料到这条消息，请当面向发送者确认。';

  @override
  String get packageNeedsNewerSignetVerifiedError =>
      '这是由较新版本的 Signet 生成的。请通过你安装 Signet 的应用商店更新后再试一次。';

  @override
  String get packageFromOlderSignetError =>
      '这是由旧版本的 Signet 生成的。远程配对需要两部手机都使用 Signet 0.4.0 或更高版本。请对方通过当初安装 Signet 的应用商店更新，然后重新生成传输包。';

  @override
  String get packageDamagedError => '此包已损坏或不完整。请检查是否完整复制，或请对方重新发送。';

  @override
  String get backupImportRepairedDateNotice =>
      '此备份中有部分内容无法读取，已修复：配对日期已重置为今天。配对本身不受影响。';

  @override
  String get backupImportRepairedLabelNotice =>
      '此备份中有部分内容无法读取，已修复：名称中的少数字符已被替换。恢复前请检查名称。配对本身不受影响。';

  @override
  String bulkBackupImportRepairedNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '此备份中有 $count 个关系的日期或名称无法读取，已修复，并在下方标记为“已修复”。恢复前请检查其名称。',
    );
    return '$_temp0';
  }

  @override
  String bulkBackupImportSkippedNewerNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '此备份中有 $count 个关系需要较新版本的 Signet，因此未显示。在完成恢复之前请保留旧手机。请只通过你最初安装 Signet 的应用商店更新，然后重新恢复。',
    );
    return '$_temp0';
  }

  @override
  String get bulkBackupImportRepairedBadge => '已修复';

  @override
  String get bulkBackupImportSummarySkippedNewer => '需要较新版本 //';

  @override
  String get bulkBackupImportNoConflictBody => '勾选要恢复的行。下面每个配对都会以原名称和原配对日期恢复。';

  @override
  String get bulkBackupImportConflictBody => '其中一些名称已在本机配对。请为每一项选择处理方式 — 默认跳过。';

  @override
  String bulkBackupImportProgressText(int committed, int total) {
    return '正在恢复 $committed/$total…';
  }

  @override
  String get bulkBackupImportRestoringButton => '恢复中…';

  @override
  String get bulkBackupImportNothingSelectedButton => '未选择任何项';

  @override
  String bulkBackupImportRestoreButton(int count) {
    return '恢复 $count 项';
  }

  @override
  String get bulkBackupImportAlreadyPairedChip => '已配对';

  @override
  String bulkBackupImportRecordMeta(String role, String date) {
    return '角色 $role · 配对于 $date';
  }

  @override
  String get bulkBackupImportSkipOption => '跳过 — 保留现有配对不动';

  @override
  String bulkBackupImportRenameOption(String label) {
    return '恢复为“$label”';
  }

  @override
  String get bulkBackupImportOverwriteOption => '覆盖现有配对';

  @override
  String get bulkBackupImportOverwriteUnavailable =>
      '这里不提供替换：有多个联系人使用这个名称，或者这份备份中的另一条已经在替换它。';

  @override
  String get bulkBackupImportCompleteHeading => '恢复完成。';

  @override
  String get bulkBackupImportSummaryRestored => '已恢复 //';

  @override
  String get bulkBackupImportSummaryRenamed => '已重命名 //';

  @override
  String get bulkBackupImportSummaryOverwrote => '已覆盖 //';

  @override
  String get bulkBackupImportSummarySkipped => '已跳过 //';

  @override
  String get bulkBackupImportSummaryFailed => '无法保存 //';

  @override
  String get bulkBackupImportFailedNote =>
      '有些联系人无法保存到这部手机。请再次恢复同一份备份来重试；已恢复的联系人会显示为已配对。';

  @override
  String get bulkBackupImportNothingChangedBody => '本机没有任何改动。';

  @override
  String get bulkBackupImportDoneBody =>
      '每个恢复的配对都使用与旧手机相同的共享密钥；只要对方没有轮换密钥，就不会察觉这次恢复。';

  @override
  String get bindingPhraseTitle => '验证绑定';

  @override
  String get bindingPhraseLoadError => '无法读取你的配对。';

  @override
  String bindingPhraseExplanation(String label) {
    return '这 4 个单词来自你和 $label 共享的密钥，可能与你们最初配对时核对的单词不同，这是正常的。请 $label 打开 Signet，进入同一个界面。当面比对，或拨打你原本就有的对方号码比对。如果两部手机现在显示相同的 4 个单词，说明配对完好。';
  }

  @override
  String get bindingPhraseMismatchHeader => '若不一致 //';

  @override
  String get bindingPhraseMismatchBody => '请解除配对并当面重新配对。在此之前，不要用这段配对验证任何通话。';

  @override
  String get bindingPhraseBackHomeButton => '返回主页';

  @override
  String get crGridTitle => '挑战-应答';

  @override
  String get crGridPrintTooltip => '打印网格';

  @override
  String crGridLoadError(String error) {
    return '无法加载网格：$error';
  }

  @override
  String crGridHeading(String label) {
    return '$label 的网格';
  }

  @override
  String crGridFallbackExplanation(String label, String row, String col) {
    return '当 $label 用不了手机但能说话时，用这张网格作为备用。你报出一个格子（如“$row × $col”），对方从你们共有的纸质副本上读出答案。你在自己这边默默比对。';
  }

  @override
  String get crGridFallbackNotice =>
      '这只是备用方案。如果能做轮换单词验证，优先用那个 — 防御更强。仅当对方没有手机时才使用本功能。';

  @override
  String get crGridSectionHeader => '网格 // 8×8 //';

  @override
  String crGridCellDialogTitle(String row, String col) {
    return '$row × $col';
  }

  @override
  String get crGridCloseButton => '关闭';

  @override
  String crPdfDocTitle(String label) {
    return 'Signet 挑战-应答 · $label';
  }

  @override
  String get crPdfCardTitle => 'SIGNET 挑战-应答卡片';

  @override
  String get crPdfWarningTitle => '像保管保险柜密码一样保管这张卡片';

  @override
  String get crPdfWarningBody =>
      '任何捡到这张卡片的人都能应答这段配对的挑战。挑战-应答只是备用方案 — 应用内的轮换单词验证仍是日常通话中更强的校验手段。如果卡片丢失，请在应用中解除这段配对并当面重新配对。';

  @override
  String get crPdfRowsHeader => '行 //';

  @override
  String get crPdfColumnsHeader => '列 //';

  @override
  String get crPdfFooter => 'Signet - 挑战-应答 v1';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAppearanceSection => '外观';

  @override
  String get settingsAppearanceBody =>
      '覆盖系统主题。“跟随系统”随设备变化；“深色”和“浅色”则固定 Signet 的主题。';

  @override
  String get settingsThemeSystemLabel => '跟随系统';

  @override
  String get settingsThemeSystemSubtitle => '随设备主题';

  @override
  String get settingsThemeDarkLabel => '深色';

  @override
  String get settingsThemeDarkSubtitle => '默认风格';

  @override
  String get settingsThemeLightLabel => '浅色';

  @override
  String get settingsThemeLightSubtitle => '日间高对比度';

  @override
  String get settingsBulkBackupSection => '批量备份';

  @override
  String get settingsBulkBackupEmptyBody => '还没有配对关系。先与别人配对，之后即可一次性备份所有配对。';

  @override
  String settingsBulkBackupBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '全部 $count 个配对关系',
      one: '你的 1 个配对关系',
    );
    return '一次备份$_temp0：一个传输包和一组 8 个单词。换手机时使用：新手机可一步恢复所有配对。';
  }

  @override
  String settingsBulkBackupAction(int count) {
    return '全部备份（$count）';
  }

  @override
  String get settingsDebugSection => '调试日志';

  @override
  String settingsDebugActiveBody(String expiry) {
    return '正在把应用活动记录到本机上的加密文件。它会在$expiry自动抹除（也可点“停止”）。导出即可提交错误报告 — 密钥会被移除，联系人会替换为 <peer-1> 这类标签，然后才离开你的手机。';
  }

  @override
  String get settingsDebugInactiveBody =>
      '关闭 — 不记录任何内容。遇到问题时，先开启，复现问题，再导出日志发给我们。日志不会包含你的密钥或联系人名称。';

  @override
  String get settingsDebugEnableAction => '开启调试日志';

  @override
  String get settingsDebugEnableFailed => '无法开启调试日志，未记录任何内容。请重试。';

  @override
  String get settingsDebugExportButton => '导出调试日志';

  @override
  String get settingsDebugStopWipeButton => '停止并抹除';

  @override
  String get settingsDebugNoLogSnackbar => '还没有捕获到调试日志。';

  @override
  String get settingsDebugExpiryIn24h => '24 小时后';

  @override
  String settingsDebugExpiryAt(String time, String date) {
    return '$date $time';
  }

  @override
  String get settingsTourSection => '引导教程';

  @override
  String get settingsTourBody => '重看首次运行教程。备份恢复后，或想重读配对说明时很有用。';

  @override
  String get settingsTourReplayAction => '重看引导';

  @override
  String get settingsAboutSection => '关于';

  @override
  String get settingsAboutBody => '应用版本、许可证、源代码、隐私政策与支持链接。';

  @override
  String get settingsAboutOpenAction => '打开关于页';

  @override
  String get settingsBulkConfirmTitle => '全部备份？';

  @override
  String get settingsUnreadableSection => '无法读取的联系人';

  @override
  String settingsUnreadableBody(int count) {
    return '有 $count 个配对联系人无法读取。可能是较新版本的 Signet 保存的，更新 Signet 后即可重新看到。它们不会显示在主页上，也不会包含在备份中。';
  }

  @override
  String get settingsUnreadableRemove => '移除无法读取的联系人';

  @override
  String get settingsUnreadableConfirmTitle => '要移除吗？';

  @override
  String get settingsUnreadableConfirmBody =>
      '这些联系人将在这部手机上解除配对，和在主页上解除配对一样。要再次与他们核验，需要重新配对。';

  @override
  String get settingsUnreadableConfirmButton => '移除';

  @override
  String get settingsUnreadableRemoveFailed => '有些无法移除，请重试。';

  @override
  String bulkBackupExportSkipsUnreadable(int count) {
    return '有 $count 个联系人无法读取，不会包含在这份备份中。请查看设置。';
  }

  @override
  String settingsBulkConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '全部 $count 个配对关系',
      one: '你的 1 个配对关系',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '全部 $count 份备份',
      one: '这份备份',
    );
    return '这会把$_temp0的共享密钥放进同一份备份。没有那 8 个单词就无法打开备份，丢失它们就等于丢失$_temp1。单词只显示一次：离开屏幕前请先写下来。';
  }

  @override
  String get settingsBulkConfirmContinue => '继续';

  @override
  String get logExportTitle => '导出调试日志';

  @override
  String get logExportScrubNotice =>
      '密钥已被移除，联系人显示为 <peer-1> 这类标签。日志仍会描述应用行为，分享前请先检查。如果提交 GitHub issue，不要在描述框里输入联系人真名 — 那个框不会做脱敏处理。';

  @override
  String get logExportFileIssueButton => '提交 GitHub issue';

  @override
  String get logExportShareButton => '分享…';

  @override
  String get logExportCopyButton => '复制到剪贴板';

  @override
  String get logExportOpenFailedSnackbar => '无法打开浏览器 — 日志已改为复制到剪贴板。';

  @override
  String get logExportShareSubject => 'Signet 调试日志';

  @override
  String get logExportCopiedSnackbar => '调试日志已复制到剪贴板。';

  @override
  String get verifyTitle => '验证';

  @override
  String get verifySectionChallenge => '挑战 //';

  @override
  String verifyAskForWordsHeading(String label) {
    return '请 $label 报出他们的 4 个单词。';
  }

  @override
  String get verifyTypeInstruction => '输入你听到的内容。点候选词可填入输入槽。';

  @override
  String get verifySectionInput => '输入 //';

  @override
  String get verifyFailHeader => '若验证失败 //';

  @override
  String get verifyFailHeading => '这通电话有问题。';

  @override
  String get verifyFailStep1 => '挂断。不要解释原因，不要争辩，不要答应他们提出的任何要求。';

  @override
  String verifyFailStep2(String label) {
    return '用你以前用过的号码回拨 $label — 通讯录里存的、写下来的、你知道的号码。不要用来电者提供的号码。';
  }

  @override
  String verifyFailStep3(String label) {
    return '如果 $label 没有接听，联系能当面确认其情况的家人或亲近的人。真正的 $label 绝不会因为你的核实而不快。';
  }

  @override
  String verifyFailStep4(String label) {
    return '如果不确定是不是 Signet 本身出了问题：点下方的“核对绑定短语”，通过你信任的渠道与 $label 比对。短语一致说明 Signet 工作正常，红色横幅意味着这通电话是假的。';
  }

  @override
  String get verifyFailCheckBindingButton => '核对绑定短语';

  @override
  String get verifyStatusOk => '结果 //';

  @override
  String get verifyStatusFail => '结果 //';

  @override
  String get verifyBannerVerified => '验证通过';

  @override
  String get verifyBannerNotVerified => '验证未通过 — 保持警惕';

  @override
  String get verifySublineVerifiedWithAction => '单词匹配，且你看到了预期的肢体动作。可以信任这通电话。';

  @override
  String get verifySublineVerified => '单词匹配。可以信任这通电话。';

  @override
  String get verifySublineWordsMismatch => '单词不匹配。可能有人正在冒充对方。';

  @override
  String get verifySublineActionMismatch => '单词匹配但肢体动作不对。请保持警惕，按验证失败处理。';

  @override
  String get verifyWhatShouldIDoButton => '我该怎么做';

  @override
  String get verifyVideoModeSemanticsLabel => '视频通话模式';

  @override
  String get verifyVideoModeSemanticsHint => '开启后在视频中额外检查一个肢体动作。';

  @override
  String get verifyVideoModeHeader => '视频通话 //';

  @override
  String get verifyVideoModeOnText => '额外要求一个肢体动作。可击败深度伪造。';

  @override
  String get verifyVideoModeOffText => '开启后额外检查一个肢体动作。';

  @override
  String get verifyWatchForHeader => '注意观察 //';

  @override
  String verifyExpectedActionText(String label, String action) {
    return '$label 应该：$action。';
  }

  @override
  String verifyExpectedActionSemantics(String label, String action) {
    return '注意观察：$label 应该 $action。';
  }

  @override
  String get verifyActionHeader => '动作 //';

  @override
  String verifyActionJudgmentPrompt(String label, String action) {
    return '单词 ✅。你看到 $label 做出动作了吗：$action？';
  }

  @override
  String verifyActionJudgmentAnnouncement(String label) {
    return '单词相符。$label 做了屏幕上显示的动作吗？请回答“看到了”或“没看到”。';
  }

  @override
  String get verifyActionNotSeenButton => '没看到';

  @override
  String get verifyActionSeenButton => '看到了';

  @override
  String verifyActionOneGesture(String label) {
    return '$label 应该只做一个动作。如果对方做了好几个，请点“没看到”。';
  }

  @override
  String verifyActionChangedNote(String label) {
    return '要观察的动作已更改：$label 读出的单词来自前一个或后一个 30 秒，这是对应的动作。';
  }

  @override
  String get verifyCheckWordsButton => '核对单词';

  @override
  String verifyOldPairingNote(String label) {
    return '这些单词与你和 $label 重新配对之前的旧配对相符。如果你们刚刚重新配对过，请当面一起再做一次。否则请把这通电话当作诈骗。';
  }

  @override
  String get verifyShowMyWords => '显示我的 4 个单词';

  @override
  String verifyShowMyWordsSubtitle(String label) {
    return '如果 $label 要验证你，念出这些单词。';
  }

  @override
  String get verifyFlagSecureBadge => '已禁止截屏';

  @override
  String verifyOwnActionWhile(String action) {
    return '……同时$action。';
  }

  @override
  String get verifyGerundLookUp => '抬头看天花板';

  @override
  String get verifyGerundLookDown => '低头看地板';

  @override
  String get verifyGerundLookLeft => '向左回头看';

  @override
  String get verifyGerundLookRight => '向右回头看';

  @override
  String get verifyGerundTouchNose => '摸鼻尖';

  @override
  String get verifyGerundTouchForehead => '摸额头';

  @override
  String get verifyGerundTouchLeftEar => '摸左耳';

  @override
  String get verifyGerundTouchRightEar => '摸右耳';

  @override
  String get verifyActionLookUp => '抬头看天花板';

  @override
  String get verifyActionLookDown => '低头看地板';

  @override
  String get verifyActionLookLeft => '向左回头看';

  @override
  String get verifyActionLookRight => '向右回头看';

  @override
  String get verifyActionTouchNose => '摸鼻尖';

  @override
  String get verifyActionTouchForehead => '摸额头';

  @override
  String get verifyActionTouchLeftEar => '摸左耳';

  @override
  String get verifyActionTouchRightEar => '摸右耳';

  @override
  String get verifyLoadError => '无法读取你的配对联系人。';

  @override
  String get verifyBackHomeButton => '返回主页';

  @override
  String get wordInputClearAllButton => '全部清除';

  @override
  String get wordInputChecking => '校验中…';

  @override
  String wordInputSlotSemantics(int index, int total) {
    return '第 $index 个单词，共 $total 个';
  }

  @override
  String get wordInputHint => '单词';

  @override
  String get wordInputInvalidWordError => '不是有效单词';

  @override
  String get wordInputClearTooltip => '清除';

  @override
  String wordsDisplaySemantics(String words, int seconds) {
    return '验证短语：$words，剩余 $seconds 秒';
  }

  @override
  String wordsDisplayCountdown(int seconds) {
    return '$seconds 秒';
  }

  @override
  String pakeUnknownWordError(int slot) {
    return '第 $slot 个单词不是 Signet 使用的单词，请检查拼写。';
  }

  @override
  String get pakeMixedLanguagesError => '8 个单词必须是同一种语言。请确认它们抄自同一处。';

  @override
  String pakeOtherLanguageWordError(int slot) {
    return '第 $slot 个单词与其他七个不是同一种语言。请确认它抄自同一处。';
  }

  @override
  String get verifyWatchForChangedAnnouncement =>
      '有新的要注意观察的动作。轻触“注意观察”这一行即可听到。';

  @override
  String wordLanguageUnknownMessage(String label) {
    return '$label 的单词使用了此版本 Signet 没有的语言。请更新 Signet 后再查看。';
  }

  @override
  String wordLanguageUnknownWarning(String label) {
    return '在此问题解决之前，你无法验证 $label。不要按紧急要求行事：请挂断电话，用你已知的号码回拨给 $label。';
  }

  @override
  String wordLanguageDamagedMessage(String label) {
    return '$label 的单词语言来自一个损坏的备份，因此无法显示其单词。请在主屏幕上长按 $label，选择“单词语言”，然后选择你们双方使用的语言。';
  }

  @override
  String get wordLanguageTitle => '单词语言';

  @override
  String get wordLanguagePickerBody =>
      'Signet 会显示一些简短的单词，你们互相读给对方听，以证明身份。请选择这些单词的语言。你和每位配对的人必须为彼此选择相同的语言。配对时，你可以为某位联系人选择不同的语言。';

  @override
  String get settingsWordLanguageSection => '单词语言';

  @override
  String get settingsWordLanguageBody => '新联系人的单词所用的语言。已有的联系人保持各自的语言。';

  @override
  String wordLanguageSampleSemantics(String language, String sample) {
    return '$language。单词示例：$sample';
  }

  @override
  String homeWordLanguageNotice(String language) {
    return 'Signet 现在可以用$language显示你的单词。要让新联系人使用它，请在设置中选择。已有的联系人仍使用英语，直到你们双方都更改：在主屏幕上长按该联系人。';
  }

  @override
  String get homeWordLanguageNoticeSettings => '设置';

  @override
  String wordLanguageRowLabel(String language) {
    return '单词：$language';
  }

  @override
  String get wordLanguageRowChange => '更改';

  @override
  String get wordLanguageRowPairingHint => '这是你们要互相读给对方听的单词。请在两部手机上选择相同的语言。';

  @override
  String get wordLanguageRowConfirmHint => '比对单词之前，两边屏幕必须显示相同的语言。';

  @override
  String wordLanguageTheyChose(String language) {
    return '对方手机选择了$language。请点“更改”并选择$language，让你们的单词一致。';
  }

  @override
  String get homeRowMenuWordLanguage => '单词语言';

  @override
  String wordLanguageDialogBody(String label) {
    return '$label 必须在他们的手机上选择相同的语言。在两部手机一致之前，验证会显示“验证未通过”。请和 $label 一起更改，绝不要因为来电者要求而更改。';
  }

  @override
  String wordLanguageChangedOn(String date) {
    return '上次更改：$date。';
  }

  @override
  String wordLanguageChangedSnackbar(String label, String language) {
    return '$label 的单词现在使用$language。请在 $label 的手机上也进行更改。';
  }

  @override
  String bulkImportOverwriteChangesLanguage(String language) {
    return '同时会把单词语言改为$language。';
  }

  @override
  String get wordLanguageRowChangeSemantics => '更改单词语言';

  @override
  String get homeRowMenuWordLanguageUnknown => '未知：请更新 Signet';

  @override
  String get backupWordsAnyLanguage => '无论 Signet 设置为哪种语言，都能读取这些单词。';

  @override
  String get wordLanguageTheyChoseUnknown =>
      '对方手机选择的单词语言是此版本 Signet 没有的。请更新 Signet，或双方都选择你们共有的语言。';

  @override
  String verifyOtherLanguageNote(String other, String label, String current) {
    return '这些单词只有按$other来读才与 $label 的配对相符，但这部手机上 $label 的单词是$current。结果仍然是“验证未通过”。通话结束后，请在两部手机上选择相同的单词语言（在主屏幕上长按 $label），然后再验证一次。';
  }

  @override
  String get pairConfirmMismatchLanguageHint =>
      '先确认两边屏幕上短语上方显示的单词语言相同。如果不同，请点“取消”，在两部手机上选择相同的语言，然后再比对一次。';

  @override
  String wordInputOtherLanguageHelper(String other, String own) {
    return '这是$other单词。此联系人的单词是$own。';
  }

  @override
  String get faqQ14 => '我的联系人的单词是另一种语言。';

  @override
  String get faqA14 =>
      '每位联系人都有一种单词语言，你和对方必须为彼此选择同一种。如果对方用另一种语言读出了正确的单词，验证仍会显示“验证未通过”，并附上说明。\n\n要解决这个问题，请一起更改：在两部手机上，于主屏幕长按该联系人，选择“单词语言”，然后选择相同的语言。只和真正的那个人一起这样做，绝不要因为来电者要求而更改。每次更改都会记录日期，并显示在该对话框中。\n\n你在首次运行时选择的语言只是新联系人的默认语言，可以在设置中更改。备份会保留每位联系人的语言。';

  @override
  String get faqQ15 => '为什么中文单词标着“测试版”？';

  @override
  String get faqA15 =>
      'Signet 的中文单词是借助词典、词频数据、计算机听辨测试和 AI 模型审阅挑选的，目的是让任意两个单词在普通话里听起来都不相似。目前还没有以中文为母语的人审核过这份词表或中文界面，中文界面同样是这样翻译的。\n\n这些单词与英文或法文单词同样安全。如果某个单词不好念、不容易听清，或容易和别的单词混淆，请通过下方的“联系我们”告诉我们。这份词表本身不会改变，所以你的配对会继续有效，但以后的新词表可以修正这类问题。';

  @override
  String get aboutLicensesButton => '开源许可';

  @override
  String get settingsChineseScriptSection => '汉字字形';

  @override
  String get settingsChineseScriptBody =>
      '这部手机上中文单词的写法。两种写法是同一组单词，所以联系人可以使用另一种写法。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get commonAppTitle => 'SIGNET';

  @override
  String get commonOfflineFreeChip => '離線可用';

  @override
  String get commonCancel => '取消';

  @override
  String get commonCancelCaps => '取消';

  @override
  String get commonDone => '完成';

  @override
  String get commonGotIt => '知道了';

  @override
  String get commonBack => '返回';

  @override
  String get commonCopyPackage => '複製傳輸包';

  @override
  String get backupStep1Header => '第 1 步 // 儲存傳輸包';

  @override
  String get backupStep1Body =>
      '把這個傳輸包儲存到這部手機以外的地方，比如電腦或 USB 隨身碟，或者把QR 碼列印出來。手機遺失時，存在手機裡的副本也會一起遺失。傳輸包不包含那 8 個字詞，單獨存在時無法還原任何內容。';

  @override
  String get backupStep1BodyNoQr =>
      '把這個傳輸包儲存到這部手機以外的地方，比如電腦或 USB 隨身碟。手機遺失時，存在手機裡的副本也會一起遺失。傳輸包不包含那 8 個字詞，單獨存在時無法還原任何內容。';

  @override
  String get backupSavePackageFile => '儲存傳輸包檔案（PACKAGE）';

  @override
  String get backupSavedAnotherWay => '我已用其他方式儲存';

  @override
  String get backupStep2Header => '第 2 步 // 把 8 個字詞放在別處';

  @override
  String get backupStep2Locked => '請先完成第 1 步。儲存傳輸包後，這裡會顯示 8 個字詞。';

  @override
  String get backupStep2Body =>
      '把這 8 個字詞寫在紙上，並寫下下方的指紋，以便知道它們對應哪個傳輸包。把紙與傳輸包分開存放，例如放在錢包裡。同時擁有兩者的人可以還原你的配對。';

  @override
  String get backupWroteOnPaper => '我已寫在紙上';

  @override
  String get backupSaveWordsFile => '改為儲存字詞檔案（WORDS）';

  @override
  String get backupWordsFileWarning =>
      '如果把字詞儲存為檔案，請放在與傳輸包不同的地方：不要放在同一個資料夾、同一部手機或同一個雲端帳號裡。';

  @override
  String backupFingerprintLine(String fingerprint) {
    return '指紋：$fingerprint（傳輸包和字詞顯示同一個指紋）';
  }

  @override
  String get backupStepDone => '已完成';

  @override
  String get backupSavedBoth => '兩者都已儲存';

  @override
  String get backupShareFailed => '無法開啟分享選單。請重試。';

  @override
  String get commonCopiedProtected =>
      '已複製。一分鐘後，或你下次回到 Signet 時，Signet 會把它從剪貼簿清除。';

  @override
  String get commonCopiedPlain => '已複製到剪貼簿。';

  @override
  String get commonCopyFailed => '無法複製，請重試。';

  @override
  String backupPackageCopiedSnackbar(String copied) {
    return '$copied請現在把它貼上到這部手機以外的地方，然後點「我已用其他方式儲存」。';
  }

  @override
  String get commonStoreSeparatelyHeader => '分開存放 //';

  @override
  String get commonRememberHeader => '切記 //';

  @override
  String get commonPakeSecretHeader => 'PAKE 密語 //';

  @override
  String get commonPairTimePhraseHeader => '配對短語 //';

  @override
  String get commonNameThisContactHeader => '為聯絡人命名 //';

  @override
  String get commonNameHintExample => '例如：Alice';

  @override
  String get labelRejectEmpty => '請輸入聯絡人名稱。';

  @override
  String get labelRejectData => '這看起來像 Signet 資料，不像名字。試試「媽媽」這樣的名稱。';

  @override
  String get labelRejectKey => '這看起來像金鑰，不像名字。試試「媽媽」這樣的名稱。';

  @override
  String get labelRejectTooLong => '名稱太長了，請換一個短一點的。';

  @override
  String get labelRestoredFallback => '已還原的聯絡人';

  @override
  String get labelRestoredSuffix => '（已還原）';

  @override
  String get scannerCameraErrorTitle => '相機沒有啟動';

  @override
  String get scannerCameraErrorBody => '請關閉正在使用相機的其他應用程式，然後重試。';

  @override
  String get scannerCameraErrorBodyPaste => '請關閉正在使用相機的其他應用程式，然後重試，或者改為貼上文字。';

  @override
  String get scannerRetry => '重試';

  @override
  String get scannerUsePaste => '改為貼上';

  @override
  String get scannerNotSignetPackage => '這個QR 碼不是 Signet 傳輸包。請掃描備份中的QR 碼。';

  @override
  String get scannerTitle => '掃描QR 碼';

  @override
  String get backupImportScanQr => '掃描QR 碼';

  @override
  String backupImportReplacedLabelNotice(String label) {
    return '備份中儲存的名稱無法使用，因此該聯絡人將以「$label」還原。還原後可以改名。';
  }

  @override
  String labelLengthCounter(int used, int max) {
    return '$used / $max';
  }

  @override
  String get pairTransportOutYourNameHeader => '你的名字（對方看到的）//';

  @override
  String get pairTransportOutYourNameDescription =>
      '選填。對方手機會把它建議為你的名字，對方可以修改。中文等文字每個字佔用更多空間，請儘量簡短。';

  @override
  String get pairTransportOutOwnPackageError => '這是你自己建立的傳輸包。請貼上對方傳回的那個。';

  @override
  String get commonPasteFromClipboard => '從剪貼簿貼上';

  @override
  String get commonUnlocking => '解鎖中…';

  @override
  String get commonSaving => '儲存中…';

  @override
  String get commonGenerating => '產生中…';

  @override
  String get commonCommitPair => '完成配對';

  @override
  String get commonConfirmPairingTitle => '確認配對';

  @override
  String commonUnlockFailedError(String error) {
    return '無法解鎖：$error';
  }

  @override
  String commonSaveFailedError(String error) {
    return '無法儲存：$error';
  }

  @override
  String get pairConfirmSaveIncompleteError =>
      'Signet 未能完成儲存此配對。請關閉 Signet 後重新開啟。如果聯絡人出現在清單中，說明已儲存；如果沒有，請一起重新配對。';

  @override
  String get pairConfirmRekeySaveIncompleteError =>
      '輪換金鑰未完成。在依靠 Signet 驗證此聯絡人之前，請在兩部手機上再輪換一次金鑰。';

  @override
  String get commonGiveContactName => '請為這個聯絡人取個名字。';

  @override
  String get commonRelationshipNotFound => '找不到這位配對聯絡人。';

  @override
  String get commonAirplaneFooter => '離線可用。Signet 從不連上網路。';

  @override
  String get homeHelpTooltip => '說明';

  @override
  String get homeMoreTooltip => '更多';

  @override
  String get homeMenuFaq => '常見問題';

  @override
  String get homeMenuContactUs => '聯絡我們';

  @override
  String get homeMenuSettings => '設定';

  @override
  String get homeMenuShowIntro => '再看一次簡介';

  @override
  String get homeMenuAbout => '關於';

  @override
  String homeErrorLoadFailed(String error) {
    return '無法讀取配對聯絡人。\n$error';
  }

  @override
  String get homeTryAgainButton => '重試';

  @override
  String get homeFabPair => '配對';

  @override
  String get homeEmptyTitle => '還沒有配對。';

  @override
  String get homeEmptyBody => '與你信任的人當面配對。之後在任何通話中都可以互相驗證。';

  @override
  String get homeEmptyPairContactButton => '配對聯絡人';

  @override
  String get homeEmptySendPackageButton => '傳送傳輸包';

  @override
  String get homeEmptyHavePackageButton => '我有傳輸包';

  @override
  String get homeEmptyRestoreBackupButton => '從備份還原';

  @override
  String get homeRenameDialogTitle => '重新命名聯絡人';

  @override
  String get homeRenameFieldLabel => '聯絡人名稱';

  @override
  String get homeRenameEmptyError => '名稱不能為空。';

  @override
  String get homeSaveButton => '儲存';

  @override
  String homeUnpairDialogTitle(String label) {
    return '解除與 $label 的配對？';
  }

  @override
  String get homeUnpairDialogBody => '這會刪除本機上的共享金鑰。之後要再驗證，只能從頭重新配對。';

  @override
  String get homeUnpairConfirmButton => '解除配對';

  @override
  String homeUnpairSnackbar(String label) {
    return '已解除與 $label 的配對。';
  }

  @override
  String get homeUndoAction => '復原';

  @override
  String get homePairMenuInPerson => '當面配對';

  @override
  String get homePairMenuInPersonSubtitle => '兩部手機放在一起，互相掃描 QR 碼';

  @override
  String get homePairMenuSendPackage => '傳送傳輸包';

  @override
  String get homePairMenuSendPackageSubtitle => '透過可信的管道與遠方的人配對';

  @override
  String get homePairMenuHavePackage => '我有傳輸包';

  @override
  String get homePairMenuHavePackageSubtitle => '匯入別人傳來的傳輸包';

  @override
  String get homePairMenuRestoreBackup => '從備份還原';

  @override
  String get homePairMenuRestoreBackupSubtitle => '從紙本備份還原配對聯絡人';

  @override
  String homeRowMenuRename(String label) {
    return '重新命名 $label';
  }

  @override
  String get homeRowMenuHapticsOn => '開啟觸覺回饋';

  @override
  String get homeRowMenuHapticsOff => '關閉觸覺回饋';

  @override
  String get homeRowMenuShowBinding => '查看綁定短語';

  @override
  String get homeRowMenuVerifyVideo => '驗證（視訊通話）';

  @override
  String get homeRowMenuVerifyVideoSubtitle => '額外檢查一個肢體動作，可抵禦深度偽造';

  @override
  String get homeRowMenuCrGrid => '挑戰-回應網格';

  @override
  String get homeRowMenuCrGridSubtitle => '對方沒有手機時的備用方案';

  @override
  String homeRowMenuRekey(String label) {
    return '輪換 $label 的金鑰';
  }

  @override
  String get homeRowMenuRekeySubtitle => '當面輪換共享金鑰';

  @override
  String get homeRowMenuBackupPaper => '備份到紙上';

  @override
  String get homeRowMenuBackupPaperSubtitle => '換新手機時可用它還原';

  @override
  String homeRowMenuUnpair(String label) {
    return '解除與 $label 的配對';
  }

  @override
  String get homeDebugBannerSemantics => '除錯記錄已開啟。雙擊前往設定管理。';

  @override
  String get homeDebugBannerText => '除錯記錄已開啟——正在記錄應用程式活動';

  @override
  String get homeSectionRelationships => '配對關係 //';

  @override
  String homeRowMetadata(String role, String fingerprint, String date) {
    return '角色：$role · $fingerprint · $date';
  }

  @override
  String get homeHapticsOffChip => '觸覺回饋 // 關';

  @override
  String get aboutTitle => '關於';

  @override
  String get aboutSectionSignet => 'SIGNET';

  @override
  String get aboutIntroBody =>
      '為人際關係打造的密碼學多重要素驗證。透過裝置對裝置的輪換碼，防禦語音與影像深度偽造的電話詐騙。零伺服器，離線優先。';

  @override
  String aboutVersionLabel(String version) {
    return '版本：$version';
  }

  @override
  String get aboutSectionLicense => '授權條款';

  @override
  String get aboutLicenseBody =>
      'AGPL-3.0-only。Signet 是自由軟體，你可以依據 GNU Affero 通用公共授權條款第 3 版使用、修改和再散布它。';

  @override
  String get aboutSectionSource => '原始碼';

  @override
  String get aboutSourceBody => '原始碼、問題追蹤與發行檔案都放在 GitHub 上。';

  @override
  String get aboutOpenRepositoryButton => '開啟儲存庫';

  @override
  String get aboutSectionPrivacy => '隱私';

  @override
  String get aboutPrivacyBody => 'Signet 不收集任何資料，也不傳送任何資料。沒有伺服器，沒有帳號，沒有遙測。';

  @override
  String get aboutPrivacyPolicyButton => '隱私政策';

  @override
  String get aboutSectionReportBug => '報告問題';

  @override
  String get aboutReportBugBody =>
      '發現了問題？請在 GitHub 回報問題（issue），註明裝置、系統版本和觸發步驟。';

  @override
  String get aboutOpenIssuesButton => '查看問題回報';

  @override
  String get aboutSectionSupport => '支持這個專案';

  @override
  String get aboutSupportBody =>
      '如果 Signet 對你有用，歡迎請我喝杯咖啡。Signet 由一人維護，應用程式內沒有任何付費方案或加購推銷。支持完全自願，非常感謝。';

  @override
  String get aboutBuyMeCoffeeButton => '請我喝咖啡';

  @override
  String get aboutCopyright => '© digital-grease';

  @override
  String get crashReportTitle => 'Signet 遇到了問題';

  @override
  String get crashReportIntroBody => '應用程式在上次使用時當機了。傳送報告有助於我們修正問題。';

  @override
  String get crashReportContainsHeading => '報告內容包括：';

  @override
  String get crashReportBulletDevice => '你的裝置 + 系統 + 應用程式版本';

  @override
  String get crashReportBulletStack =>
      '一份堆疊追蹤，其中所有密碼學材料（配對金鑰、驗證碼、備份資料）都會在離開你的手機前替換為 [redacted:N] 標記。';

  @override
  String get crashReportChooseHeading => '選擇傳送方式：';

  @override
  String get crashReportDismissButton => '關閉';

  @override
  String get crashReportCopyLogButton => '複製記錄';

  @override
  String get crashReportFileIssueButton => '回報問題';

  @override
  String get crashReportCopiedSnackbar => '當機記錄已複製到剪貼簿。';

  @override
  String get crashReportOpenFailedSnackbar => '無法開啟瀏覽器。當機記錄已複製到剪貼簿，你可以手動貼上。';

  @override
  String get crashReportTruncatedSnackbar =>
      '追蹤內容較長——完整記錄已複製到剪貼簿。請貼在 GitHub 上截斷標記的下方。';

  @override
  String get faqTitle => '常見問題';

  @override
  String get faqQ1 => 'Signet 到底是做什麼的？';

  @override
  String get faqA1 =>
      'Signet 讓你確認打電話、傳簡訊或視訊給你的人，確實是他自稱的那個人——即使對方聲音很像、知道你的個人資料，而且催你辦急事。你只需要與信任的人當面配對一次。之後任何一方都可以請對方提供一組 4 個字詞的驗證碼，只有真正配對的裝置才能產生。';

  @override
  String get faqQ2 => '「驗證通過」究竟證明了什麼？';

  @override
  String get faqA2 =>
      '它證明對方實際拿得到與你配對的那部手機，而且那部手機沒有被入侵。它不能證明對方的聲音是真的——如果深度偽造的同時，還能脅迫拿著真手機的人唸出驗證碼，仍然會通過驗證。Signet 的目標是把攻擊者的成本從「複製聲音」提高到「還得偷到一部已解鎖的手機」。';

  @override
  String get faqQ3 => '4 個字詞的驗證碼為什麼一直在變？';

  @override
  String get faqA3 =>
      '每組驗證碼只在 30 秒內有效。這樣即使攻擊者在一次真實通話中錄下了驗證碼，之後也無法重複使用。Signet 接受目前這個時段以及前後各一個時段的驗證碼，所以時鐘稍有偏差或唸得慢一點，也不會讓正常的驗證失敗。';

  @override
  String get faqQ4 => '如果驗證碼對不上怎麼辦？';

  @override
  String get faqA4 =>
      '把它當作危險訊號。真正配對聯絡人的驗證碼幾乎總能一次對上。對不上就掛斷電話，透過你自己原本就知道的其他管道（已知的電話號碼、當面、共同的朋友）聯絡本人，確認無誤後再處理對方提出的任何要求。';

  @override
  String get faqQ5 => 'Signet 能看到我的配對或驗證碼嗎？';

  @override
  String get faqA5 =>
      '不能。Signet 沒有伺服器、沒有帳號、沒有遙測、沒有統計分析，在 Android 上也不要求網路存取權限。你們的共享金鑰儲存在手機的安全硬體（Keychain/Keystore）中，不會離開裝置。即使 Signet 明天消失，你的資料也不會跟著消失。';

  @override
  String get faqQ6 => '手機丟了怎麼辦？';

  @override
  String get faqA6 =>
      '如果遺失前做過備份，可以用「從備份還原」把配對聯絡人還原到新手機。對方什麼都不用做，甚至不會察覺發生過還原。如果沒有備份，配對就遺失了，需要在新裝置上與該聯絡人當面重新配對。';

  @override
  String get faqQ12 => '怎樣安全地儲存備份？';

  @override
  String get faqA12 =>
      '備份分兩部分：傳輸包檔案（PACKAGE，已加密）和用來解鎖它的 8 個字詞。兩者要分開存放。把傳輸包檔案存到手機以外的地方，比如電腦或 USB 隨身碟。把 8 個字詞寫在紙上，放在別處，比如錢包裡。同時拿到兩部分的人就能向你的聯絡人冒充你，所以不要把它們放在一起，也不要用訊息傳送這些字詞。還原時，點「從備份還原」，載入傳輸包檔案，再輸入 8 個字詞。';

  @override
  String get faqQ7 => '可以和多個人配對嗎？';

  @override
  String get faqA7 => '可以。想配對幾個人都行——每次配對彼此獨立。每段關係都有自己的金鑰，某段配對遭到破解，不會洩露或影響其他配對。';

  @override
  String get faqQ8 => '挑戰-回應網格是什麼？';

  @override
  String get faqA8 =>
      '一種離線備用方案，用於對方無法使用手機的情況。你們雙方各有一張由共享金鑰推導出的相同 8×8 字詞網格。你問「orange-anchor 對應的短語是什麼？」——對方查表（在應用程式裡或列印的卡片上）並唸出三個字詞的答案。與你的應用程式顯示的一致，就表示配對是真的。';

  @override
  String get faqQ9 => '視訊通話驗證為什麼要求做肢體動作？';

  @override
  String get faqA9 =>
      'AI 語音和影像深度偽造越來越逼真。即時深度偽造聽到你要那 4 個字詞，可以馬上說出幾個字詞——但正確的字詞只能來自配對裝置，所以普通驗證才有效。然而，深度偽造聽到你唸出「摸摸耳朵」這類隨機指令，也能立刻模仿這個動作。所以 Signet 把動作也變成由共享金鑰推導出的內容：只有真正的配對裝置知道這個時段應該做哪個動作。開啟視訊通話模式後，必須同時符合兩個條件才算通過：4 個字詞正確，而且對方做出了預期的動作。沒有配對裝置的深度偽造只能用猜的，兩者都猜中的機率，每 30 秒時段約為 100 兆分之一。如果你使用螢幕閱讀器，通話時請戴耳機：Signet 不會自己唸出這個動作，但輕觸「注意觀察」這一行會唸出來，開著擴音時對方可能會聽到。';

  @override
  String get faqQ10 => '為什麼沒有帳號？需要還原怎麼辦？';

  @override
  String get faqA10 =>
      '帳號意味著伺服器、密碼，以及一條攻擊者（或法院傳票）不必碰到你的手機就能取得配對資料的途徑。Signet 之所以存在，正是因為其他驗證工具都有這樣的途徑。還原只能手動：趁現在一切平靜，做一份備份，放在手機遺失時你拿得到的地方。';

  @override
  String get faqQ11 => '有人要求我跳過驗證步驟。';

  @override
  String get faqA11 =>
      '不要跳過。真正的配對聯絡人明白為什麼需要驗證，不會施壓要你略過。製造緊迫感又要求跳過驗證，正是騙子突破安全防線的慣用手法。如果你正被施壓，在確認之前，先把這通電話當成惡意的。';

  @override
  String get faqQ13 => 'Signet 提示需要更新。';

  @override
  String get faqA13 =>
      'Signet 有時會改變配對碼和備份的產生方式，舊版本無法讀取新的格式。\n\n如果配對碼或備份來自較新版本的 Signet，它會提示這部手機需要更新。配對時，如果對方手機的版本較舊，它會提示對方手機需要更新。配對需要兩部手機都使用 Signet 0.4.0 或更新版本。備份可以在相同或更新版本的 Signet 上還原。\n\n只透過你當初安裝 Signet 的應用程式商店更新。Signet 從不透過連結或檔案傳送更新。如果有人傳給你更新，或催你安裝某個東西才能完成配對，那就是詐騙。\n\nSignet 0.3.6 及更早版本無法顯示這則提示，而是會說這不是 Signet 的配對碼。';

  @override
  String get faqStillStuckHeader => '仍未解決 //';

  @override
  String get faqStillStuckBody =>
      '在這裡沒找到答案？請在 GitHub 回報問題（issue），註明你的裝置、系統版本以及你想做什麼。';

  @override
  String get faqContactUsButton => '聯絡我們';

  @override
  String get onboardingSkipButton => '跳過';

  @override
  String get onboardingBriefingTag1 => '簡報 // 01';

  @override
  String get onboardingBriefingTag2 => '簡報 // 02';

  @override
  String get onboardingBriefingTag3 => '簡報 // 03';

  @override
  String get onboardingSlide1Title => '驗證電話那頭是誰。';

  @override
  String get onboardingSlide1Body =>
      '深度偽造的語音和影像可以冒充任何人——家人、同事、消息來源。當有人帶著緊迫感來電，要錢、要幫忙、要存取權限時，Signet 讓你可以向對方要一組輪換的 4 個字詞，只有對方真正的手機才能產生。字詞對得上，你就能確認。';

  @override
  String get onboardingSlide2Title => '當面配對一次。';

  @override
  String get onboardingSlide2Body =>
      '見面時互相掃描對方的 QR 碼，即可完成兩部手機的配對。共享金鑰只儲存在兩台裝置上——硬體保護、離線、不用雲端。沒有東西可以被傳票調閱，沒有東西可以被釣魚騙走，也沒有要同步的伺服器，因為它根本不存在。';

  @override
  String get onboardingSlide3Title => '請對方唸出短語。';

  @override
  String get onboardingSlide3Body =>
      '通話時開啟 Signet，點選聯絡人，請對方唸出他們的 4 個字詞。把聽到的輸入進去。綠色橫幅 = 驗證通過，可以信任這通電話。紅色橫幅 = 不要信任。掛斷電話，改用你原本就知道的號碼回撥。';

  @override
  String get onboardingContinueButton => '繼續';

  @override
  String get pairStartTitle => '配對聯絡人';

  @override
  String get pairStartHeading => '這個人叫什麼名字？';

  @override
  String get pairStartPrivacyNote => '只儲存在你的手機上。用一眼能認出的名字——「媽媽」、「小張」、「財務部」。';

  @override
  String get pairStartNameLabel => '名稱';

  @override
  String get pairStartEmptyNameError => '請為這個聯絡人輸入名稱。';

  @override
  String get pairStartContinueButton => '繼續';

  @override
  String pairExchangeTitlePair(String contact) {
    return '與 $contact 配對';
  }

  @override
  String pairExchangeTitleRekey(String contact) {
    return '與 $contact 輪換金鑰';
  }

  @override
  String get pairExchangeFallbackContact => '聯絡人';

  @override
  String get pairInPersonIntro =>
      '請在同一個房間裡，把兩部手機放在一起。只掃描對方手機本身，絕不要掃描照片或視訊通話裡的碼：那些碼可能被掉包。';

  @override
  String get pairInPersonRoleHint => '先說好誰先開始。那部手機點「發起」，另一部手機點「加入」。';

  @override
  String get pairInPersonNextButton => '下一步';

  @override
  String get pairInPersonNextHint => '等對方手機顯示出它自己的碼後再點。';

  @override
  String get pairInPersonShowWordsButton => '顯示字詞';

  @override
  String get pairInPersonFinishHint => '等對方手機顯示出 4 個字詞後再點。';

  @override
  String get pairInPersonShowAgainButton => '再次顯示我的碼';

  @override
  String get pairInPersonQrLabel => '配對QR 碼';

  @override
  String get pairCodeAlreadyScannedNotice => '已經掃描過了。請等對方手機顯示下一個碼。';

  @override
  String get pairInPersonPasteFromClipboard => '從剪貼簿貼上';

  @override
  String pairInPersonCopiedSnackbar(String status) {
    return '$status請你自己把它交給對方手機，然後當面一起核對 4 個字詞。';
  }

  @override
  String get pairInPersonStartButton => '發起';

  @override
  String get pairInPersonStartSubtitle => '這部手機先顯示它的碼。';

  @override
  String get pairInPersonJoinButton => '加入';

  @override
  String get pairInPersonJoinSubtitle => '這部手機先掃描對方的手機。';

  @override
  String pairInPersonStepLabel(int step) {
    return '第 $step 步，共 3 步';
  }

  @override
  String get pairInPersonShowHeading => '讓對方手機掃描這個碼。';

  @override
  String get pairInPersonShowRevealHeading => '讓對方手機也掃描這個碼。';

  @override
  String get pairInPersonScanHeading => '掃描對方的手機。';

  @override
  String get pairInPersonScanRevealHeading => '再掃描一次對方的手機。';

  @override
  String get pairInPersonPreparing => '正在準備…';

  @override
  String get pairInPersonDeriving => '正在計算字詞…';

  @override
  String get pairInPersonJoinIdleHint =>
      '還沒有掃描到。對方手機是否點了「發起」並顯示出碼？如果兩部手機都點了「加入」，請在兩部手機上都點「重新開始」，然後讓其中一部點「發起」。';

  @override
  String get pairInPersonStartIdleHint =>
      '還沒有掃描到。對方手機是否點了「加入」並顯示出碼？如果兩部手機都點了「發起」，請在兩部手機上都點「重新開始」，然後讓其中一部點「加入」。';

  @override
  String get pairInPersonShowAsText => '以文字顯示這個碼';

  @override
  String get pairInPersonShowAsQr => '顯示QR 碼';

  @override
  String get pairInPersonCopyCode => '複製配對碼';

  @override
  String get pairInPersonPasteInstead => '改為貼上配對碼';

  @override
  String get pairInPersonPasteHeading => '貼上對方手機的碼';

  @override
  String get pairInPersonPasteLabel => '配對碼';

  @override
  String get pairInPersonPasteSubmit => '使用這個碼';

  @override
  String get pairInPersonPasteEmptyError => '請先貼上對方手機的碼。';

  @override
  String get pairInPersonBackToCamera => '返回相機';

  @override
  String get pairInPersonStartOverButton => '重新開始';

  @override
  String get pairInPersonStartOverBoth =>
      '在兩部手機上都點「重新開始」；如果某部手機已經顯示字詞，就在那部手機上點「不一致」。然後一部手機點「發起」，另一部點「加入」。';

  @override
  String get pairCodeMalformedNotice => '這個碼不完整或已損壞。請重新掃描或貼上。';

  @override
  String get pairCodeNotPairingNotice => '這不是 Signet 的配對碼。請掃描對方手機配對畫面上的碼。';

  @override
  String get pairCodeMultipleNotice => '一次只貼上一個碼。';

  @override
  String get pairCodePeerNeedsUpdateNotice =>
      '對方手機上的 Signet 版本較舊，需要先更新才能配對。只透過當初安裝 Signet 的應用程式商店更新。Signet 從不透過連結或檔案傳送更新。';

  @override
  String get pairCodeThisNeedsUpdateNotice =>
      '這個碼來自較新版本的 Signet。請先在這部手機上更新 Signet，而且只透過你當初安裝它的應用程式商店更新。Signet 從不透過連結或檔案傳送更新。';

  @override
  String get pairFailStartStart => '這部手機掃描到的是「發起」的碼。必須一部手機點「發起」，另一部點「加入」。';

  @override
  String get pairFailJoinJoin => '這部手機掃描到的是「加入」的碼。必須一部手機點「發起」，另一部點「加入」。';

  @override
  String get pairFailSecondCode => '中途掃描到另一個不同的碼，為了安全，這次配對已結束。';

  @override
  String get pairFailWrongCode => '這個碼屬於另一個步驟，為了安全，這次配對已結束。';

  @override
  String get pairFailRevealMismatch =>
      '停止。最後一個碼與第一個碼不符，可能有人在干擾。如果對方手機顯示了字詞，請在那部手機上點「不一致」。不要儲存這次配對。';

  @override
  String get pairFailTimedOut => '時間過長，這次配對已結束。';

  @override
  String get pairFailInternal => '這部手機出了問題。';

  @override
  String get pairExchangeCameraPermissionTitle => '相機權限已關閉。';

  @override
  String pairExchangeCameraPermissionBody(String path) {
    return 'Signet 只在掃描配對QR 碼時需要相機。請在手機設定中開啟：$path。';
  }

  @override
  String get pairCameraSettingsPathIos => '設定 → Signet → 相機';

  @override
  String get pairCameraSettingsPathAndroid => '應用程式 → Signet → 權限 → 相機';

  @override
  String get pairConfirmTitle => '確認';

  @override
  String get pairConfirmRekeyTitle => '確認輪換金鑰';

  @override
  String get pairConfirmHeading => '和對方螢幕上的一致嗎？';

  @override
  String get pairConfirmInstructions => '大聲唸出來。兩台裝置上的四個字詞應完全一致。';

  @override
  String get pairConfirmMatchButton => '一致';

  @override
  String get pairConfirmMismatchButton => '不一致——重新開始';

  @override
  String get pairConfirmMismatchDialogTitle => '短語不一致？';

  @override
  String get pairConfirmMismatchDialogBody =>
      '如果你的短語和對方的不一致，就是出了問題——可能是掃描失敗，也可能是有人試圖從中攔截。比較安全的做法是放棄這次配對，重新開始。';

  @override
  String get pairConfirmStartOverButton => '重新開始';

  @override
  String pairConfirmRekeySnackbar(String label) {
    return '已與 $label 輪換配對金鑰。';
  }

  @override
  String pairConfirmPairedSnackbar(String label) {
    return '已與 $label 配對。';
  }

  @override
  String get pairConfirmStateIncompleteError => '配對狀態不完整。';

  @override
  String get pairConfirmRekeyTargetMissingError => '要輪換的配對關係已不存在。';

  @override
  String get pairCompleteTitle => '配對完成';

  @override
  String get pairCompleteCommittedHeader => '配對已儲存 //';

  @override
  String get pairCompleteHeading => '你們兩人都還在場。\n現在就試一次驗證。';

  @override
  String pairCompletePracticeBody(String label) {
    return '現在是練習的最好時機。請 $label 開啟 Signet，點你的名字，唸出「顯示我的 4 個字詞」畫面上的 4 個字詞。把你聽到的輸入驗證欄位。綠色橫幅出現時，你就知道它真的可用。';
  }

  @override
  String get pairCompleteRemoteHeading => '已遠端配對。\n下次通話時練習一次。';

  @override
  String pairCompleteRemoteBody(String label) {
    return '下次和 $label 說話時，請對方開啟 Signet，點你的名字，唸出「顯示我的 4 個字詞」畫面上的 4 個字詞。把你聽到的輸入驗證欄位。綠色橫幅出現時，你就知道它真的可用。';
  }

  @override
  String pairCompleteRemoteWaitNote(String label) {
    return '$label 貼上你的回應包之後，驗證才會生效。';
  }

  @override
  String get pairCompleteFallbackPeer => '對方';

  @override
  String get pairCompleteTipBody => '跳過也沒關係，之後隨時可以從首頁驗證。但成本最低的練習機會就是現在。';

  @override
  String pairCompleteVerifyNowButton(String label) {
    return '立即驗證 $label';
  }

  @override
  String get pairCompleteSkipButton => '跳過——以後再說';

  @override
  String get pairTransportInImportTitle => '匯入傳輸包';

  @override
  String get pairTransportInIncomingHeader => '收到的傳輸包 //';

  @override
  String get pairTransportInPasteInstruction => '貼上傳送者給你的文字。以「signet:tp1:」開頭。';

  @override
  String get pairTransportInPakeDescription =>
      '這 8 個字詞是傳送者透過可信的管道（紙本、加密電子郵件、事先見面時的約定）告訴你的。不要接受透過未經驗證的語音電話傳來的這些字詞。';

  @override
  String get pairTransportInUnlockButton => '解鎖傳輸包';

  @override
  String get pairTransportInPasteEmptyError => '請貼上傳送者給你的傳輸包。';

  @override
  String get pairTransportInWordsIncompleteError => '請輸入傳送者給的全部 8 個字詞。';

  @override
  String pairTransportInProcessFailedError(String error) {
    return '處理傳輸包失敗：$error';
  }

  @override
  String get pairTransportInPhraseInstruction =>
      '逐一、按順序核對全部 8 個字詞，並確認兩部手機都剛好顯示 8 個。請與傳送者當面核對，或撥打你原本就有的對方號碼核對。不要透過訊息核對，也絕不要使用別人給你的電話或號碼。如果全部一致，這個傳輸包就是真的。';

  @override
  String get pairTransportInResponseHeader => '你的回應包 //';

  @override
  String get pairTransportInResponseInstruction =>
      '用你收到對方傳輸包的同一個管道，把它傳回給傳送者。對方貼上後即可完成配對。';

  @override
  String get pairTransportInCopyResponseButton => '複製回應包';

  @override
  String get pairTransportOutNewPackageTitle => '建立傳輸包';

  @override
  String get pairTransportOutShareWaitTitle => '分享並等待';

  @override
  String get pairTransportOutNameDescription => '這是配對後在你的首頁上顯示的聯絡人名稱，只有你看得到。';

  @override
  String get pairTransportOutGenerateButton => '產生傳輸包';

  @override
  String pairTransportOutGenerateError(String error) {
    return '無法產生傳輸包：$error';
  }

  @override
  String get pairTransportOutOutgoingHeader => '發出的傳輸包 //';

  @override
  String pairTransportOutOutgoingInstruction(String label) {
    return '把這段文字傳給 $label。加密電子郵件、Signal、專人遞送紙本、列印的 QR 碼——任何管道都可以。只有同時擁有下面 8 個 PAKE 字詞的人才能使用它。';
  }

  @override
  String get pairTransportOutChannelWarning =>
      '這 8 個字詞務必透過與傳輸包不同的管道傳送。絕不要使用別人提供的電話或號碼。紙本、事先見面時的約定，或另一段已配對的 Signet 關係，都比口頭唸出來安全。';

  @override
  String get pairTransportOutReceiveHeader => '接收回應包 //';

  @override
  String pairTransportOutReceiveInstruction(String label) {
    return '$label 會傳一個回應包給你。請把它貼在這裡。';
  }

  @override
  String get pairTransportOutPasteEmptyError => '請貼上接收方傳來的回應包。';

  @override
  String get pairTransportOutUnlockResponseButton => '解鎖回應包';

  @override
  String pairTransportOutUnlockFailedError(String error) {
    return '無法解鎖回應包：$error';
  }

  @override
  String get pairingWeakKeyInPersonError =>
      '停止。這個配對碼不安全。請在兩部手機上都取消配對，然後重新開始。不要相信任何一部手機上顯示的字詞。';

  @override
  String get pairingWeakKeyRemoteError =>
      '這個傳輸包不安全，可能已被竄改。請關閉這個畫面，重新產生傳輸包，並換一種與之前不同的方式傳送。不要相信任何一部手機上顯示的字詞。';

  @override
  String pairTransportOutPhraseInstruction(String label) {
    return '逐一、按順序核對全部 8 個字詞，並確認兩部手機都剛好顯示 8 個。請與 $label 當面核對，或撥打你原本就有的對方號碼核對。不要透過訊息核對，也絕不要使用別人給你的電話或號碼。如果全部一致，配對就是真的。';
  }

  @override
  String get backupExportTitle => '備份到紙上';

  @override
  String backupExportGenerateError(String error) {
    return '無法產生備份：$error';
  }

  @override
  String backupExportHeading(String label) {
    return '備份 $label';
  }

  @override
  String backupExportIntro(String label) {
    return '有了備份，手機遺失後就能在新手機上還原這段配對。$label 的手機不會察覺任何變化。';
  }

  @override
  String get backupExportStoreSeparatelyBody =>
      '這份備份分兩部分：傳輸包，以及解鎖它的 8 個字詞。請分開存放。如果有人同時拿到兩者，就能在自己的手機上還原這段配對。';

  @override
  String backupExportRememberBody(String label) {
    return '如果有別人同時拿到了傳輸包和這 8 個字詞，請立即解除與 $label 的配對並當面重新配對。備份裡包含與目前配對相同的金鑰。';
  }

  @override
  String get backupImportRestoreTitle => '還原備份';

  @override
  String get backupImportConfirmTitle => '確認匯入';

  @override
  String get backupImportFileTooLargeError =>
      '這個檔案太大，不可能是 Signet 備份。請選擇你建立備份時儲存的那個小文字檔案。';

  @override
  String get backupImportFileReadError => '無法讀取所選檔案。請重新選擇。';

  @override
  String get backupImportPasteEmptyError => '請先載入或貼上你的備份傳輸包。';

  @override
  String get backupImportWordsIncompleteError => '請輸入全部 8 個備份字詞。';

  @override
  String get backupImportPackageHeader => '第 1 步 // 傳輸包';

  @override
  String get backupImportLoadPackageFile => '載入傳輸包檔案（PACKAGE）';

  @override
  String get backupImportWordsHeader => '第 2 步 // 8 個字詞';

  @override
  String get backupImportLoadWordsFile => '載入字詞檔案（WORDS）';

  @override
  String get backupImportIsWordsError => '這是 8 個字詞，不是傳輸包。請放在第 2 步。';

  @override
  String get backupImportIsPackageError => '這是傳輸包，不是字詞。請放在第 1 步。';

  @override
  String get backupImportNoWordsError => '那裡沒有找到備份字詞。請找一行 8 個字詞。';

  @override
  String backupImportFingerprintMismatchError(String package, String words) {
    return '這些字詞屬於另一個備份（傳輸包 $package，字詞 $words）。請找指紋為 $package 的字詞。';
  }

  @override
  String get backupImportLegacyNotice =>
      '這是舊版備份，字詞和傳輸包儲存在同一個檔案裡。還原後，請重新備份並刪除此檔案。';

  @override
  String get backupImportNotBackupError => '不是有效的 Signet 備份。';

  @override
  String get backupImportInvitationError => '這是配對邀請，不是備份。請從首頁使用配對流程。';

  @override
  String get backupImportClipboardEmptyError => '剪貼簿是空的。';

  @override
  String get backupImportPasteInstruction =>
      '載入傳輸包檔案（PACKAGE），或貼上傳輸包文字。它以「signet:tp1:」開頭。';

  @override
  String get backupImportWordsInstruction => '輸入你記下的 8 個字詞，或載入你儲存的字詞檔案（WORDS）。';

  @override
  String get backupImportUnlockButton => '解鎖備份';

  @override
  String get backupImportRestoredPeerHeader => '還原的聯絡人 //';

  @override
  String get backupImportRoleLabel => '角色 //';

  @override
  String get backupImportOriginallyLabel => '原配對時間 //';

  @override
  String get backupImportHapticsLabel => '觸覺回饋 //';

  @override
  String get backupImportHapticsOff => '關';

  @override
  String get backupImportHapticsOn => '開';

  @override
  String get backupImportWhatItDoesHeader => '這會做什麼 //';

  @override
  String backupImportWhatItDoesBody(String label) {
    return '這部手機將與 $label 使用與舊手機相同的金鑰材料共享金鑰。$label 的手機不會察覺任何變化。如果備份之後對方已與其他人輪換過金鑰，驗證會失敗，直到你當面重新配對。';
  }

  @override
  String get backupImportCommitButton => '確認匯入';

  @override
  String get bulkBackupExportSetupTitle => '全部備份';

  @override
  String get bulkBackupExportReadyTitle => '批次備份已產生';

  @override
  String bulkBackupExportPrepareError(String error) {
    return '無法準備備份：$error';
  }

  @override
  String get bulkBackupExportNoSecretsError => '沒有任何配對關係的金鑰可讀取。';

  @override
  String get bulkBackupExportEmptyTitle => '還沒有可備份的內容。';

  @override
  String get bulkBackupExportEmptyBody => '請先與別人配對，再回到這裡建立批次備份。';

  @override
  String bulkBackupExportReadyHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個配對關係',
      one: '1 個配對關係',
    );
    return '備份 $_temp0';
  }

  @override
  String get bulkBackupExportReadyBody =>
      '下面所有配對聯絡人會放進同一份備份：一個傳輸包，以及解鎖它的 8 個字詞。兩者分開存放，之後用它們把所有配對遷移到新手機。';

  @override
  String get bulkBackupExportGenerateButton => '產生批次備份';

  @override
  String bulkBackupExportDoneHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已備份 $count 個配對關係',
      one: '已備份 1 個配對關係',
    );
    return '$_temp0';
  }

  @override
  String get bulkBackupExportStoreSeparatelyBody =>
      '這份備份分兩部分：傳輸包，以及解鎖它的 8 個字詞。請分開存放。如果有人同時拿到兩者，就能在自己的手機上還原所有配對。';

  @override
  String get bulkBackupExportWordsInstruction =>
      '把這 8 個字詞寫到安全的地方。在新手機上輸入它們即可一次解鎖全部內容。';

  @override
  String get bulkBackupExportPackageInstruction =>
      '全部配對的集合，用上面的 8 個字詞加密。可透過任何管道分享——字詞會把它鎖住。';

  @override
  String bulkBackupExportShareSubject(int count) {
    return 'Signet 批次備份 - $count 位聯絡人';
  }

  @override
  String get bulkBackupExportRememberBody =>
      '如果有別人同時拿到了傳輸包和這 8 個字詞，請解除其中所有聯絡人的配對並當面重新配對。備份裡包含與你目前配對相同的金鑰。';

  @override
  String get bulkBackupImportTitle => '批次還原';

  @override
  String get bulkBackupImportDoneTitle => '已還原';

  @override
  String bulkBackupImportGenericError(String error) {
    return '錯誤：$error';
  }

  @override
  String bulkBackupImportPreviewHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個配對關係',
      one: '1 個配對關係',
    );
    return '還原 $_temp0';
  }

  @override
  String get packageNeedsNewerSignetError =>
      '需要較新版本的 Signet。請只透過你當初安裝 Signet 的應用程式商店更新。Signet 從不透過連結或檔案傳送更新。如果你沒有預料到這則訊息，請當面向傳送者確認。';

  @override
  String get packageNeedsNewerSignetVerifiedError =>
      '這是由較新版本的 Signet 產生的。請透過你當初安裝 Signet 的應用程式商店更新後再試一次。';

  @override
  String get packageFromOlderSignetError =>
      '這是由舊版本的 Signet 產生的。遠端配對需要兩部手機都使用 Signet 0.4.0 或更新版本。請對方透過他當初安裝 Signet 的應用程式商店更新，然後重新產生傳輸包。';

  @override
  String get packageDamagedError => '這個傳輸包已損壞或不完整。請檢查是否完整複製，或請對方重新傳送。';

  @override
  String get backupImportRepairedDateNotice =>
      '此備份中有部分內容無法讀取，已修復：配對日期已重設為今天。配對本身不受影響。';

  @override
  String get backupImportRepairedLabelNotice =>
      '此備份中有部分內容無法讀取，已修復：名稱中的少數字元已被替換。還原前請檢查名稱。配對本身不受影響。';

  @override
  String bulkBackupImportRepairedNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '此備份中有 $count 個配對關係的日期或名稱無法讀取，已修復，並在下方標記為「已修復」。還原前請檢查其名稱。',
    );
    return '$_temp0';
  }

  @override
  String bulkBackupImportSkippedNewerNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '此備份中有 $count 個配對關係需要較新版本的 Signet，因此未顯示。在完成還原之前請保留舊手機。請只透過你當初安裝 Signet 的應用程式商店更新，然後重新還原。',
    );
    return '$_temp0';
  }

  @override
  String get bulkBackupImportRepairedBadge => '已修復';

  @override
  String get bulkBackupImportSummarySkippedNewer => '需要較新版本 //';

  @override
  String get bulkBackupImportNoConflictBody => '勾選要還原的項目。下面每個配對都會以原名稱和原配對日期還原。';

  @override
  String get bulkBackupImportConflictBody => '其中一些名稱已在本機配對。請為每一項選擇處理方式——預設跳過。';

  @override
  String bulkBackupImportProgressText(int committed, int total) {
    return '正在還原 $committed/$total…';
  }

  @override
  String get bulkBackupImportRestoringButton => '還原中…';

  @override
  String get bulkBackupImportNothingSelectedButton => '未選擇任何項目';

  @override
  String bulkBackupImportRestoreButton(int count) {
    return '還原 $count 項';
  }

  @override
  String get bulkBackupImportAlreadyPairedChip => '已配對';

  @override
  String bulkBackupImportRecordMeta(String role, String date) {
    return '角色 $role · 配對於 $date';
  }

  @override
  String get bulkBackupImportSkipOption => '跳過——保留現有配對不動';

  @override
  String bulkBackupImportRenameOption(String label) {
    return '還原為「$label」';
  }

  @override
  String get bulkBackupImportOverwriteOption => '覆寫現有配對';

  @override
  String get bulkBackupImportOverwriteUnavailable =>
      '這裡不提供替換：有多個聯絡人使用這個名稱，或者這份備份中的另一筆已經在替換它。';

  @override
  String get bulkBackupImportCompleteHeading => '還原完成。';

  @override
  String get bulkBackupImportSummaryRestored => '已還原 //';

  @override
  String get bulkBackupImportSummaryRenamed => '已重新命名 //';

  @override
  String get bulkBackupImportSummaryOverwrote => '已覆寫 //';

  @override
  String get bulkBackupImportSummarySkipped => '已跳過 //';

  @override
  String get bulkBackupImportSummaryFailed => '無法儲存 //';

  @override
  String get bulkBackupImportFailedNote =>
      '有些聯絡人無法儲存到這部手機。請再次還原同一份備份來重試；已還原的聯絡人會顯示為已配對。';

  @override
  String get bulkBackupImportNothingChangedBody => '這部手機上沒有任何變更。';

  @override
  String get bulkBackupImportDoneBody =>
      '每個還原的配對都使用與舊手機相同的共享金鑰；只要對方沒有輪換金鑰，就不會察覺這次還原。';

  @override
  String get bindingPhraseTitle => '驗證綁定';

  @override
  String get bindingPhraseLoadError => '無法讀取你的配對。';

  @override
  String bindingPhraseExplanation(String label) {
    return '這 4 個字詞來自你和 $label 共享的金鑰，可能與你們最初配對時核對的字詞不同，這是正常的。請 $label 開啟 Signet，點開同一個畫面。當面比對，或撥打你原本就有的對方號碼比對。如果兩部手機現在顯示相同的 4 個字詞，就表示配對完好。';
  }

  @override
  String get bindingPhraseMismatchHeader => '若不一致 //';

  @override
  String get bindingPhraseMismatchBody => '請解除配對並當面重新配對。在此之前，不要用這段配對驗證任何通話。';

  @override
  String get bindingPhraseBackHomeButton => '返回首頁';

  @override
  String get crGridTitle => '挑戰-回應';

  @override
  String get crGridPrintTooltip => '列印網格';

  @override
  String crGridLoadError(String error) {
    return '無法載入網格：$error';
  }

  @override
  String crGridHeading(String label) {
    return '$label 的網格';
  }

  @override
  String crGridFallbackExplanation(String label, String row, String col) {
    return '當 $label 用不了手機但能說話時，用這張網格作為備用。你報出一個格子（如「$row × $col」），對方從你們共有的紙本副本上讀出答案。你在自己這邊默默比對。';
  }

  @override
  String get crGridFallbackNotice =>
      '這只是備用方案。如果能做輪換字詞驗證，優先用那個——防禦更強。僅當對方沒有手機時才使用本功能。';

  @override
  String get crGridSectionHeader => '網格 // 8×8 //';

  @override
  String crGridCellDialogTitle(String row, String col) {
    return '$row × $col';
  }

  @override
  String get crGridCloseButton => '關閉';

  @override
  String crPdfDocTitle(String label) {
    return 'Signet 挑戰-回應 · $label';
  }

  @override
  String get crPdfCardTitle => 'SIGNET 挑戰-回應卡片';

  @override
  String get crPdfWarningTitle => '像保管保險箱密碼一樣保管這張卡片';

  @override
  String get crPdfWarningBody =>
      '任何撿到這張卡片的人都能回應這段配對的挑戰。挑戰-回應只是備用方案——應用程式內的輪換字詞驗證，仍是日常通話中更強的檢查方式。如果卡片遺失，請在應用程式中解除這段配對，並當面重新配對。';

  @override
  String get crPdfRowsHeader => '橫列 //';

  @override
  String get crPdfColumnsHeader => '直行 //';

  @override
  String get crPdfFooter => 'Signet - 挑戰-回應 v1';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsAppearanceSection => '外觀';

  @override
  String get settingsAppearanceBody =>
      '可以不跟隨系統主題。「跟隨系統」隨裝置變化；「深色」和「淺色」則固定 Signet 的主題。';

  @override
  String get settingsThemeSystemLabel => '跟隨系統';

  @override
  String get settingsThemeSystemSubtitle => '隨裝置主題';

  @override
  String get settingsThemeDarkLabel => '深色';

  @override
  String get settingsThemeDarkSubtitle => '預設風格';

  @override
  String get settingsThemeLightLabel => '淺色';

  @override
  String get settingsThemeLightSubtitle => '日間高對比';

  @override
  String get settingsBulkBackupSection => '批次備份';

  @override
  String get settingsBulkBackupEmptyBody => '還沒有配對關係。先與別人配對，之後即可一次備份所有配對。';

  @override
  String settingsBulkBackupBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '全部 $count 個配對關係',
      one: '你的 1 個配對關係',
    );
    return '一次備份$_temp0：一個傳輸包和一組 8 個字詞。換手機時使用：新手機可一步還原所有配對。';
  }

  @override
  String settingsBulkBackupAction(int count) {
    return '全部備份（$count）';
  }

  @override
  String get settingsDebugSection => '除錯記錄';

  @override
  String settingsDebugActiveBody(String expiry) {
    return '正在把應用程式活動記錄到這部手機上的加密檔案。它會在$expiry自動抹除（也可以點「停止」）。匯出後即可傳送錯誤報告——金鑰會被移除，聯絡人會換成 <peer-1> 這類標籤，然後才離開你的手機。';
  }

  @override
  String get settingsDebugInactiveBody =>
      '關閉——不記錄任何內容。遇到問題時，先開啟，重現問題，再匯出記錄傳給我們。記錄不會包含你的金鑰或聯絡人名稱。';

  @override
  String get settingsDebugEnableAction => '開啟除錯記錄';

  @override
  String get settingsDebugEnableFailed => '無法開啟除錯記錄，未記錄任何內容。請重試。';

  @override
  String get settingsDebugExportButton => '匯出除錯記錄';

  @override
  String get settingsDebugStopWipeButton => '停止並抹除';

  @override
  String get settingsDebugNoLogSnackbar => '目前還沒有除錯記錄。';

  @override
  String get settingsDebugExpiryIn24h => '24 小時後';

  @override
  String settingsDebugExpiryAt(String time, String date) {
    return '$date $time';
  }

  @override
  String get settingsTourSection => '導覽';

  @override
  String get settingsTourBody => '再看一次第一次使用時的導覽。還原備份後，或想重讀配對說明時很有用。';

  @override
  String get settingsTourReplayAction => '重看導覽';

  @override
  String get settingsAboutSection => '關於';

  @override
  String get settingsAboutBody => '應用程式版本、授權條款、原始碼、隱私政策與贊助連結。';

  @override
  String get settingsAboutOpenAction => '開啟「關於」';

  @override
  String get settingsBulkConfirmTitle => '全部備份？';

  @override
  String get settingsUnreadableSection => '無法讀取的聯絡人';

  @override
  String settingsUnreadableBody(int count) {
    return '有 $count 個配對聯絡人無法讀取。可能是較新版本的 Signet 儲存的，更新 Signet 後即可重新看到。它們不會顯示在首頁上，也不會包含在備份中。';
  }

  @override
  String get settingsUnreadableRemove => '移除無法讀取的聯絡人';

  @override
  String get settingsUnreadableConfirmTitle => '要移除嗎？';

  @override
  String get settingsUnreadableConfirmBody =>
      '這些聯絡人將在這部手機上解除配對，和在首頁上解除配對一樣。要再次與他們驗證，需要重新配對。';

  @override
  String get settingsUnreadableConfirmButton => '移除';

  @override
  String get settingsUnreadableRemoveFailed => '有些無法移除，請重試。';

  @override
  String bulkBackupExportSkipsUnreadable(int count) {
    return '有 $count 個聯絡人無法讀取，不會包含在這份備份中。請查看設定。';
  }

  @override
  String settingsBulkConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '全部 $count 個配對關係',
      one: '你的 1 個配對關係',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '全部 $count 份備份',
      one: '這份備份',
    );
    return '這會把$_temp0的共享金鑰放進同一份備份。沒有那 8 個字詞就無法開啟備份，遺失它們就等於失去$_temp1。字詞只顯示一次：離開這個畫面前請先寫下來。';
  }

  @override
  String get settingsBulkConfirmContinue => '繼續';

  @override
  String get logExportTitle => '匯出除錯記錄';

  @override
  String get logExportScrubNotice =>
      '金鑰已被移除，聯絡人顯示為 <peer-1> 這類標籤。記錄仍會描述應用程式的行為，分享前請先檢查。如果在 GitHub 回報問題（issue），不要在描述欄裡輸入聯絡人的真實姓名——那個欄位不會自動遮蔽。';

  @override
  String get logExportFileIssueButton => '在 GitHub 回報問題';

  @override
  String get logExportShareButton => '分享…';

  @override
  String get logExportCopyButton => '複製到剪貼簿';

  @override
  String get logExportOpenFailedSnackbar => '無法開啟瀏覽器——記錄已改為複製到剪貼簿。';

  @override
  String get logExportShareSubject => 'Signet 除錯記錄';

  @override
  String get logExportCopiedSnackbar => '除錯記錄已複製到剪貼簿。';

  @override
  String get verifyTitle => '驗證';

  @override
  String get verifySectionChallenge => '挑戰 //';

  @override
  String verifyAskForWordsHeading(String label) {
    return '請 $label 報出他們的 4 個字詞。';
  }

  @override
  String get verifyTypeInstruction => '輸入你聽到的內容。點選建議的字詞即可填入空格。';

  @override
  String get verifySectionInput => '輸入 //';

  @override
  String get verifyFailHeader => '若驗證失敗 //';

  @override
  String get verifyFailHeading => '這通電話有問題。';

  @override
  String get verifyFailStep1 => '掛斷電話。不要解釋原因，不要爭辯，不要答應他們提出的任何要求。';

  @override
  String verifyFailStep2(String label) {
    return '用你以前用過的號碼回撥 $label——通訊錄裡存的、寫下來的、你知道的號碼。不要用來電者提供的號碼。';
  }

  @override
  String verifyFailStep3(String label) {
    return '如果 $label 沒有接聽，聯絡能當面確認其情況的家人或親近的人。真正的 $label 絕不會因為你的核實而不快。';
  }

  @override
  String verifyFailStep4(String label) {
    return '如果不確定是不是 Signet 本身出了問題：點下方的「核對綁定短語」，透過你信任的管道與 $label 比對。短語一致，表示 Signet 運作正常，紅色橫幅代表這通電話是假的。';
  }

  @override
  String get verifyFailCheckBindingButton => '核對綁定短語';

  @override
  String get verifyStatusOk => '結果 //';

  @override
  String get verifyStatusFail => '結果 //';

  @override
  String get verifyBannerVerified => '驗證通過';

  @override
  String get verifyBannerNotVerified => '驗證未通過——提高警覺';

  @override
  String get verifySublineVerifiedWithAction => '字詞相符，且你看到了預期的肢體動作。可以信任這通電話。';

  @override
  String get verifySublineVerified => '字詞相符。可以信任這通電話。';

  @override
  String get verifySublineWordsMismatch => '字詞不相符。可能有人正在冒充對方。';

  @override
  String get verifySublineActionMismatch => '字詞相符但肢體動作不對。請提高警覺，按驗證失敗處理。';

  @override
  String get verifyWhatShouldIDoButton => '我該怎麼做？';

  @override
  String get verifyVideoModeSemanticsLabel => '視訊通話模式';

  @override
  String get verifyVideoModeSemanticsHint => '開啟後在視訊畫面中額外檢查一個肢體動作。';

  @override
  String get verifyVideoModeHeader => '視訊通話 //';

  @override
  String get verifyVideoModeOnText => '額外要求一個肢體動作，用來對抗深度偽造。';

  @override
  String get verifyVideoModeOffText => '開啟後額外檢查一個肢體動作。';

  @override
  String get verifyWatchForHeader => '注意觀察 //';

  @override
  String verifyExpectedActionText(String label, String action) {
    return '$label 應該：$action。';
  }

  @override
  String verifyExpectedActionSemantics(String label, String action) {
    return '注意觀察：$label 應該 $action。';
  }

  @override
  String get verifyActionHeader => '動作 //';

  @override
  String verifyActionJudgmentPrompt(String label, String action) {
    return '字詞 ✅。你看到 $label 做出動作了嗎：$action？';
  }

  @override
  String verifyActionJudgmentAnnouncement(String label) {
    return '字詞相符。$label 做了螢幕上顯示的動作嗎？請回答「看到了」或「沒看到」。';
  }

  @override
  String get verifyActionNotSeenButton => '沒看到';

  @override
  String get verifyActionSeenButton => '看到了';

  @override
  String verifyActionOneGesture(String label) {
    return '$label 應該只做一個動作。如果對方做了好幾個，請點「沒看到」。';
  }

  @override
  String verifyActionChangedNote(String label) {
    return '要觀察的動作已變更：$label 唸出的字詞屬於前一個或後一個 30 秒時段，這是對應的動作。';
  }

  @override
  String get verifyCheckWordsButton => '核對字詞';

  @override
  String verifyOldPairingNote(String label) {
    return '這些字詞與你和 $label 輪換金鑰之前的舊配對相符。如果你們剛剛輪換過金鑰，請當面一起再做一次。否則請把這通電話當作詐騙。';
  }

  @override
  String get verifyShowMyWords => '顯示我的 4 個字詞';

  @override
  String verifyShowMyWordsSubtitle(String label) {
    return '如果 $label 要驗證你，唸出這些字詞。';
  }

  @override
  String get verifyFlagSecureBadge => '已禁止截圖';

  @override
  String verifyOwnActionWhile(String action) {
    return '……同時$action。';
  }

  @override
  String get verifyGerundLookUp => '抬頭看天花板';

  @override
  String get verifyGerundLookDown => '低頭看地板';

  @override
  String get verifyGerundLookLeft => '向左回頭看';

  @override
  String get verifyGerundLookRight => '向右回頭看';

  @override
  String get verifyGerundTouchNose => '摸鼻尖';

  @override
  String get verifyGerundTouchForehead => '摸額頭';

  @override
  String get verifyGerundTouchLeftEar => '摸左耳';

  @override
  String get verifyGerundTouchRightEar => '摸右耳';

  @override
  String get verifyActionLookUp => '抬頭看天花板';

  @override
  String get verifyActionLookDown => '低頭看地板';

  @override
  String get verifyActionLookLeft => '向左回頭看';

  @override
  String get verifyActionLookRight => '向右回頭看';

  @override
  String get verifyActionTouchNose => '摸鼻尖';

  @override
  String get verifyActionTouchForehead => '摸額頭';

  @override
  String get verifyActionTouchLeftEar => '摸左耳';

  @override
  String get verifyActionTouchRightEar => '摸右耳';

  @override
  String get verifyLoadError => '無法讀取你的配對聯絡人。';

  @override
  String get verifyBackHomeButton => '返回首頁';

  @override
  String get wordInputClearAllButton => '全部清除';

  @override
  String get wordInputChecking => '檢查中…';

  @override
  String wordInputSlotSemantics(int index, int total) {
    return '第 $index 個字詞，共 $total 個';
  }

  @override
  String get wordInputHint => '字詞';

  @override
  String get wordInputInvalidWordError => '不是有效字詞';

  @override
  String get wordInputClearTooltip => '清除';

  @override
  String wordsDisplaySemantics(String words, int seconds) {
    return '驗證短語：$words，剩餘 $seconds 秒';
  }

  @override
  String wordsDisplayCountdown(int seconds) {
    return '$seconds 秒';
  }

  @override
  String pakeUnknownWordError(int slot) {
    return '第 $slot 個字詞不是 Signet 使用的字詞，請檢查是否輸入正確。';
  }

  @override
  String get pakeMixedLanguagesError => '8 個字詞必須是同一種語言。請確認它們抄自同一處。';

  @override
  String pakeOtherLanguageWordError(int slot) {
    return '第 $slot 個字詞與其他七個不是同一種語言。請確認它抄自同一處。';
  }

  @override
  String get verifyWatchForChangedAnnouncement =>
      '有新的動作需要注意觀察。輕觸「注意觀察」這一行即可聽到。';

  @override
  String wordLanguageUnknownMessage(String label) {
    return '$label 的字詞使用了此版本 Signet 沒有的語言。請更新 Signet 後再查看。';
  }

  @override
  String wordLanguageUnknownWarning(String label) {
    return '在這個問題解決之前，你無法驗證 $label。不要照著緊急要求去做：請掛斷電話，用你原本就知道的號碼回撥給 $label。';
  }

  @override
  String wordLanguageDamagedMessage(String label) {
    return '$label 的字詞語言來自一個損壞的備份，因此無法顯示其字詞。請在首頁上長按 $label，選擇「字詞語言」，然後選擇你們雙方使用的語言。';
  }

  @override
  String get wordLanguageTitle => '字詞語言';

  @override
  String get wordLanguagePickerBody =>
      'Signet 會顯示一些簡短的字詞，你們互相讀給對方聽，以證明身份。請選擇這些字詞的語言。你和每位配對的人必須為彼此選擇相同的語言。配對時，你可以為某位聯絡人選擇不同的語言。';

  @override
  String get settingsWordLanguageSection => '字詞語言';

  @override
  String get settingsWordLanguageBody => '新聯絡人的字詞所用的語言。已有的聯絡人保持各自的語言。';

  @override
  String wordLanguageSampleSemantics(String language, String sample) {
    return '$language。字詞範例：$sample';
  }

  @override
  String homeWordLanguageNotice(String language) {
    return 'Signet 現在可以用$language顯示你的字詞。要讓新聯絡人使用它，請在設定中選擇。已有的聯絡人仍使用英文，直到你們雙方都更改：在首頁上長按該聯絡人。';
  }

  @override
  String get homeWordLanguageNoticeSettings => '設定';

  @override
  String wordLanguageRowLabel(String language) {
    return '字詞：$language';
  }

  @override
  String get wordLanguageRowChange => '更改';

  @override
  String get wordLanguageRowPairingHint => '這是你們要互相讀給對方聽的字詞。請在兩部手機上選擇相同的語言。';

  @override
  String get wordLanguageRowConfirmHint => '比對字詞之前，兩邊螢幕必須顯示相同的語言。';

  @override
  String wordLanguageTheyChose(String language) {
    return '對方手機選擇了$language。請點「更改」並選擇$language，讓你們的字詞一致。';
  }

  @override
  String get homeRowMenuWordLanguage => '字詞語言';

  @override
  String wordLanguageDialogBody(String label) {
    return '$label 必須在他們的手機上選擇相同的語言。在兩部手機一致之前，驗證會顯示「驗證未通過」。請和 $label 一起更改，絕不要因為來電者要求而更改。';
  }

  @override
  String wordLanguageChangedOn(String date) {
    return '上次更改：$date。';
  }

  @override
  String wordLanguageChangedSnackbar(String label, String language) {
    return '$label 的字詞現在使用$language。請在 $label 的手機上也進行更改。';
  }

  @override
  String bulkImportOverwriteChangesLanguage(String language) {
    return '同時會把字詞語言改為$language。';
  }

  @override
  String get wordLanguageRowChangeSemantics => '更改字詞語言';

  @override
  String get homeRowMenuWordLanguageUnknown => '未知：請更新 Signet';

  @override
  String get backupWordsAnyLanguage => '無論 Signet 設定為哪種語言，都能讀取這些字詞。';

  @override
  String get wordLanguageTheyChoseUnknown =>
      '對方手機選擇的字詞語言是此版本 Signet 沒有的。請更新 Signet，或雙方都選擇你們共有的語言。';

  @override
  String verifyOtherLanguageNote(String other, String label, String current) {
    return '這些字詞只有以$other來讀，才與 $label 的配對相符，但這部手機上 $label 的字詞是$current。結果仍然是「驗證未通過」。通話結束後，請在兩部手機上選擇相同的字詞語言（在首頁上長按 $label），然後再驗證一次。';
  }

  @override
  String get pairConfirmMismatchLanguageHint =>
      '先確認兩邊螢幕上短語上方顯示的字詞語言相同。如果不同，請點「取消」，在兩部手機上選擇相同的語言，然後再比對一次。';

  @override
  String wordInputOtherLanguageHelper(String other, String own) {
    return '這是$other字詞。此聯絡人的字詞是$own。';
  }

  @override
  String get faqQ14 => '我的聯絡人的字詞是另一種語言。';

  @override
  String get faqA14 =>
      '每位聯絡人都有一種字詞語言，你和對方必須為彼此選擇同一種。如果對方用另一種語言讀出了正確的字詞，驗證仍會顯示「驗證未通過」，並附上說明。\n\n要解決這個問題，請一起更改：在兩部手機上，於首頁長按該聯絡人，選擇「字詞語言」，然後選擇相同的語言。只和真正的那個人一起這樣做，絕不要因為來電者要求而更改。每次更改都會記錄日期，並顯示在該對話方塊中。\n\n你第一次使用時選擇的語言，只是新聯絡人的預設語言，可以在設定中更改。備份會保留每位聯絡人的語言。';

  @override
  String get faqQ15 => '為什麼中文字詞標著「測試版」？';

  @override
  String get faqA15 =>
      'Signet 的中文字詞是借助辭典、詞頻資料、電腦聽辨測試和 AI 模型審閱挑選的，目的是讓任兩個字詞在國語裡聽起來都不相似。目前還沒有以中文為母語的人審核過這份字詞表或中文介面，中文介面同樣是這樣翻譯的。\n\n這些字詞與英文或法文字詞同樣安全。如果某個字詞不好唸、不容易聽清楚，或容易和別的字詞混淆，請透過下方的「聯絡我們」告訴我們。這份字詞表本身不會改變，所以你的配對會繼續有效，但日後的新字詞表可以修正這類問題。';

  @override
  String get aboutLicensesButton => '開放原始碼授權';

  @override
  String get settingsChineseScriptSection => '漢字字形';

  @override
  String get settingsChineseScriptBody =>
      '這部手機上中文字詞的寫法。兩種寫法是同一組字詞，所以聯絡人可以使用另一種寫法。';
}
