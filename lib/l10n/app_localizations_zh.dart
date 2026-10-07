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
  String get commonPackageCopiedSnackbar => '传输包已复制到剪贴板';

  @override
  String get commonSharePackage => '分享传输包';

  @override
  String get commonIveSavedIt => '已保存';

  @override
  String get commonStoreSeparatelyHeader => '分开存放 //';

  @override
  String get commonRememberHeader => '切记 //';

  @override
  String get commonPakeSecretHeader => 'PAKE 密语 //';

  @override
  String get commonBackupPackageHeader => '备份包 //';

  @override
  String get commonPairTimePhraseHeader => '配对短语 //';

  @override
  String get commonNameThisContactHeader => '为联系人命名 //';

  @override
  String get commonNameHintExample => '例如：Alice';

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
  String get commonAirplaneFooter => '离线 // 无网络 · 无遥测 · STRONGBOX';

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
      '如果丢失前做过纸质备份，可以用“从备份恢复”流程把配对联系人恢复到新手机 — 对方什么都不用做，甚至不会察觉发生过恢复。如果没有备份，配对就丢失了，需要在新设备上与该联系人当面重新配对。';

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
      'AI 语音和视频深度伪造越来越强。能听到你索要 4 个单词的实时深度伪造可以直接复述 — 但普通验证之所以有效，正是因为这些单词只能来自配对设备。然而，能听到你念出“摸摸耳朵”这类随机指令的深度伪造，也能立刻模仿这个动作。所以 Signet 把动作也变成由共享密钥推导的内容：只有真正的配对设备知道这个窗口内应该做哪个动作。开启视频通话模式后，通过验证需要同时满足：4 个单词正确，且对方做出了预期动作。没有配对设备的深度伪造只能靠猜，合计成功率在每 30 秒窗口内约为 100 万亿分之一。';

  @override
  String get faqQ10 => '为什么没有账号？需要恢复怎么办？';

  @override
  String get faqA10 =>
      '账号意味着服务器、密码，以及攻击者（或传票）可以绕过你的手机触达配对数据的通路。Signet 的存在正是因为其他认证工具都有这样的通路。恢复是手动的：趁现在一切正常，导出纸质备份，放在手机丢失时你能拿到的地方。';

  @override
  String get faqQ11 => '有人要求我跳过验证步骤。';

  @override
  String get faqA11 =>
      '不要跳过。真实的配对联系人明白验证存在的意义，不会施压让你绕过它。制造紧迫感并要求跳过验证，正是骗子瓦解安全防线的惯用手法。如果你正被施压，在证明清白之前，默认这通电话是恶意的。';

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
  String get pairExchangeIntro => '把两部手机放在一起。双方都需要完成以下两步。';

  @override
  String get pairExchangeStep1Title => '出示我的二维码';

  @override
  String get pairExchangeStep1Subtitle => '让对方扫描你的二维码。';

  @override
  String get pairExchangeStep2Title => '扫描对方二维码';

  @override
  String get pairExchangeStep2Subtitle => '把相机对准对方的二维码。';

  @override
  String get pairExchangeStep3Title => '粘贴字符串（开发）';

  @override
  String get pairExchangeStep3Subtitle => '仅用于双模拟器测试。跳过相机。';

  @override
  String get pairExchangeDerivingStatus => '正在派生共享密钥…';

  @override
  String get pairExchangeWaitingStatus => '等待两步都完成…';

  @override
  String get pairExchangeShowHeading => '让对方扫描这个。';

  @override
  String get pairExchangeShowDoneButton => '对方已扫描 — 我这边完成';

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
  String get pairExchangeDevHeading => '开发：粘贴交换';

  @override
  String get pairExchangeDevInstructions => '把“你的字符串”复制到另一台模拟器的粘贴框，再把对方的粘贴到下面。';

  @override
  String get pairExchangeDevYourString => '你的字符串';

  @override
  String get pairExchangeDevCopyButton => '复制';

  @override
  String get pairExchangeDevCopiedSnackbar => '已复制到剪贴板';

  @override
  String get pairExchangeDevTheirString => '对方的字符串';

  @override
  String get pairExchangeDevSubmitButton => '提交';

  @override
  String get pairExchangeDevSubmittingButton => '提交中…';

  @override
  String get pairExchangePasteEmptyError => '请粘贴另一台设备的配对字符串。';

  @override
  String get pairingErrorNotPairingQr => '不是 Signet 配对二维码（协议或版本不对）。';

  @override
  String pairingErrorBadPayloadLength(int actual) {
    return '解码结果为 $actual 字节，应为 32 字节。';
  }

  @override
  String pairingErrorDecodeFailed(String error) {
    return '无法解码配对二维码：$error';
  }

  @override
  String pairingErrorBadKeyLength(int actual, int expected) {
    return '扫描到的密钥为 $actual 字节，应为 $expected 字节。';
  }

  @override
  String pairingErrorDeriveFailed(String error) {
    return '派生共享密钥失败：$error';
  }

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
    return '现在练习验证最容易。请 $label 打开 Signet，点你的名字，念出“显示我的单词”界面上的 4 个单词。把你听到的输入到验证输入框。绿色横幅出现时，你就知道它是真实可用的。';
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
      '通过你接收 PAKE 密语的同一条可信渠道，请发件人确认他们的屏幕上出现这 4 个单词。一致即表示传输包真实可信。';

  @override
  String get pairTransportInResponseHeader => '你的响应包 //';

  @override
  String get pairTransportInResponseInstruction =>
      '用接收对方传输包的同一条渠道把它发回给发件人。对方粘贴后即可完成配对。';

  @override
  String get pairTransportInCopyResponseButton => '复制响应包';

  @override
  String get pairTransportInResponseCopiedSnackbar => '响应包已复制到剪贴板';

  @override
  String get pairTransportOutNewPackageTitle => '新建传输包';

  @override
  String get pairTransportOutShareWaitTitle => '分享并等待';

  @override
  String get pairTransportOutNameDescription =>
      '这是配对后显示在你主页上的名称。对方导入传输包时会看到它作为提示，但可以在其设备上改名。';

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
  String get pairTransportOutCopyWordsButton => '复制单词';

  @override
  String get pairTransportOutWordsCopiedSnackbar => 'PAKE 单词已复制';

  @override
  String get pairTransportOutChannelWarning =>
      '这 8 个单词务必通过与传输包不同的渠道发送。绝不要通过临时拨通的语音电话。纸质、事先见面的约定，或另一段已配对的 Signet 关系，都比口头念出来更安全。';

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
    return '通过传递 PAKE 密语的同一条可信渠道，请 $label 确认这 4 个单词与屏幕上一致。一致即表示配对真实有效。';
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
    return '把这些写下来，手机丢失后就能在新手机上恢复这段配对。$label 的手机不会察觉任何变化。';
  }

  @override
  String get backupExportStoreSeparatelyBody =>
      'PAKE 密语和备份包必须存放在不同的物理载体上。如果有人同时拿到两者，就能在自己的手机上恢复这段配对。纸质分放两处（家里 + 保管箱）是合理的起点；同步到云端的密码管理器则不行。';

  @override
  String get backupExportWordsInstruction =>
      '把这 8 个单词写到安全的地方。在新手机上输入它们即可解锁传输包。';

  @override
  String get backupExportPackageInstruction =>
      '在新手机上扫描这个二维码，或复制粘贴下面的文本。它与上面的 PAKE 密语是不同的载体 — 不要存放在一起。';

  @override
  String backupExportShareSubject(String label) {
    return 'Signet 备份 - $label';
  }

  @override
  String backupExportRememberBody(String label) {
    return '如果这张纸被别人发现，请立即解除与 $label 的配对并当面重新配对。备份里包含与当前配对相同的共享密钥。';
  }

  @override
  String get backupImportRestoreTitle => '恢复备份';

  @override
  String get backupImportConfirmTitle => '确认导入';

  @override
  String get backupImportFileReadError => '无法读取所选文件。';

  @override
  String backupImportFileReadFailedError(String error) {
    return '无法读取文件：$error';
  }

  @override
  String backupImportInvalidFileError(String message) {
    return '该文件不是有效的 Signet 备份：$message';
  }

  @override
  String get backupImportPasteEmptyError => '请粘贴你的备份包。';

  @override
  String get backupImportWordsIncompleteError => '请输入你分开存放的 8 个 PAKE 单词。';

  @override
  String get backupImportNotBackupError => '不是有效的 Signet 备份。';

  @override
  String get backupImportInvitationError => '这是配对邀请，不是备份。请从主页使用配对流程。';

  @override
  String get backupImportClipboardEmptyError => '剪贴板是空的。请先复制你的备份包。';

  @override
  String get backupImportPasteInstruction =>
      '粘贴纸上的备份包。以“signet:tp1:”开头。如果扫的是二维码，请粘贴扫出的文本。';

  @override
  String get backupImportLoadFromFileButton => '从文件载入';

  @override
  String get backupImportWordsInstruction =>
      '来自你纸质记录或密码管理器的 8 个单词 — 与上面的传输包分开存放。';

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
      '下面所有配对联系人会打包进一个加密文件，配一个 8 单词 PAKE。文件和单词分开存放，之后用它们把所有配对迁移到新手机。';

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
      'PAKE 密语和备份包必须存放在不同的物理载体上。如果有人同时拿到两者，就能在自己的手机上恢复所有配对。纸质分放两处（家里 + 保管箱）是合理的起点；同步到云端的密码管理器则不行。';

  @override
  String get bulkBackupExportWordsInstruction =>
      '把这 8 个单词写到安全的地方。在新手机上输入它们即可一次性解锁全部内容。';

  @override
  String get bulkBackupExportCopyPakeButton => '复制 PAKE';

  @override
  String get bulkBackupExportPakeCopiedSnackbar => 'PAKE 单词已复制到剪贴板';

  @override
  String get bulkBackupExportPackageInstruction =>
      '全部配对的集合，用上面的 8 个单词加密。可通过任何渠道分享 — 单词是它的封印。';

  @override
  String bulkBackupExportShareLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个配对关系（批量）',
      one: '1 个配对关系（批量）',
    );
    return '$_temp0';
  }

  @override
  String bulkBackupExportShareSubject(int count) {
    return 'Signet 批量备份 - $count 位联系人';
  }

  @override
  String get bulkBackupExportRememberBody =>
      '如果这个文件和这 8 个单词同时被别人发现，请解除其中所有配对关系并当面重新配对。备份包含与你当前配对相同的共享密钥。';

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
  String get bulkBackupImportNoLabel => '（无名称）';

  @override
  String bulkBackupImportRecordMeta(String role, String date) {
    return '角色 $role · 配对于 $date';
  }

  @override
  String get bulkBackupImportSkipOption => '跳过 — 保留现有配对不动';

  @override
  String bulkBackupImportRenameOption(String label) {
    return '将恢复的副本重命名为“$label（已恢复）”';
  }

  @override
  String get bulkBackupImportOverwriteOption => '覆盖现有配对';

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
    return '这 4 个单词在你和 $label 配对的那一刻生成。请 $label 打开 Signet 进入同一个界面。两台设备上的 4 个单词一致，即表示配对完好。';
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
      one: '1 个配对关系',
    );
    return '把$_temp0备份到一个加密文件，配一个 8 单词 PAKE。换手机时使用 — 新手机可一步解锁所有配对。';
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
  String settingsBulkConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '全部 $count 个配对关系',
      one: '1 个配对关系',
    );
    return '这会把$_temp0的共享密钥导出到一个文件。丢失 8 单词 PAKE 就等于丢失全部 $count 份备份。PAKE 只会显示一次 — 关闭屏幕前请先抄写下来。';
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
    return '如果不确定是不是 Signet 本身出了问题：进入主页，点“查看绑定短语”，通过你信任的渠道与 $label 比对。短语一致说明 Signet 工作正常，红色横幅意味着这通电话是假的。';
  }

  @override
  String get verifyStatusOk => '状态 // 200 正常';

  @override
  String get verifyStatusFail => '状态 // 403 不匹配';

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
  String get verifyActionNotSeenButton => '没看到';

  @override
  String get verifyActionSeenButton => '看到了';

  @override
  String get verifyShowMyWords => '显示我的 4 个单词';

  @override
  String verifyShowMyWordsSubtitle(String label) {
    return '如果 $label 要验证你，念出这些单词。';
  }

  @override
  String get verifyFlagSecureBadge => 'FLAG_SECURE';

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
}
