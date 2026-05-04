import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../globals.dart';
import '../models/personnel_profile.dart';
import '../services/file_manager/file_sharer.dart';
import '../theme/app_theme.dart';

class PersonnelFullInfoTab extends StatefulWidget {
  const PersonnelFullInfoTab({super.key});

  @override
  State<PersonnelFullInfoTab> createState() => _PersonnelFullInfoTabState();
}

class _PersonnelFullInfoTabState extends State<PersonnelFullInfoTab> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd.MM.yyyy');
  final _fileSharer = FileSharer();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _militaryUnitController = TextEditingController();
  final _positionController = TextEditingController();
  final _staffRankController = TextEditingController();
  final _rankController = TextEditingController();
  final _militarySpecialtyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionOrderNumberController = TextEditingController();
  final _familyStatusController = TextEditingController();
  final _housingStatusController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _ratingController = TextEditingController();

  PersonnelProfile? _profile;
  DateTime? _birthDate;
  DateTime? _positionOrderDate;
  DateTime? _serviceStartDate;
  DateTime? _contractEndDate;
  DateTime? _mobilizationDate;
  String _serviceType = 'contract';
  String _currentStatus = 'в строю';
  bool _relocationReady = false;

  List<RankHistoryEntry> _rankHistory = [];
  List<EducationEntry> _education = [];
  List<OnlineCourseEntry> _onlineCourses = [];
  List<FamilyMemberEntry> _familyMembers = [];
  List<AwardEntry> _awards = [];
  List<EventHistoryEntry> _combatParticipation = [];
  List<EventHistoryEntry> _wounds = [];
  List<LanguageSkillEntry> _languageSkills = [];

  List<PersonnelProfile> _groupProfiles = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _isLoadingGroup = false;

  bool get _isEditingOwnProfile {
    return _profile?.uid == Globals.profileManager.currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _patronymicController.dispose();
    _militaryUnitController.dispose();
    _positionController.dispose();
    _staffRankController.dispose();
    _rankController.dispose();
    _militarySpecialtyController.dispose();
    _phoneController.dispose();
    _positionOrderNumberController.dispose();
    _familyStatusController.dispose();
    _housingStatusController.dispose();
    _homeAddressController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groupId = Globals.profileManager.currentGroupId;
    final uid = Globals.profileManager.currentUserId;
    if (groupId == null || uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profile = await Globals.personnelProfileService.loadOwnProfile(
        groupId: groupId,
        uid: uid,
      );
      _applyProfile(profile);
      if (Globals.profileManager.isCurrentGroupAdmin) {
        await _loadGroupProfiles();
      }
    } catch (e) {
      Globals.errorNotificationManager.showError(
        'Помилка завантаження повної інформації: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupProfiles() async {
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) return;

    setState(() => _isLoadingGroup = true);
    try {
      final profiles = await Globals.personnelProfileService.loadGroupProfiles(
        groupId,
      );
      if (mounted) {
        setState(() => _groupProfiles = profiles);
      }
    } catch (e) {
      Globals.errorNotificationManager.showError(
        'Помилка завантаження профілів групи: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoadingGroup = false);
    }
  }

  void _applyProfile(PersonnelProfile profile) {
    _profile = profile;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _patronymicController.text = profile.patronymic;
    _militaryUnitController.text = profile.militaryUnit;
    _positionController.text = profile.position;
    _staffRankController.text = profile.staffRank;
    _rankController.text = profile.rank;
    _militarySpecialtyController.text = profile.militarySpecialty;
    _phoneController.text = profile.phone;
    _positionOrderNumberController.text = profile.positionOrderNumber;
    _familyStatusController.text = profile.familyStatus;
    _housingStatusController.text = profile.housingStatus;
    _homeAddressController.text = profile.homeAddress;
    _ratingController.text = profile.rating;
    _birthDate = profile.birthDate;
    _positionOrderDate = profile.positionOrderDate;
    _serviceType = profile.serviceType.isEmpty
        ? 'contract'
        : profile.serviceType;
    _serviceStartDate = profile.serviceStartDate;
    _contractEndDate = profile.contractEndDate;
    _mobilizationDate = profile.mobilizationDate;
    _relocationReady = profile.relocationReady ?? false;
    _currentStatus = profile.currentStatus.isEmpty
        ? 'в строю'
        : profile.currentStatus;
    _rankHistory = List.of(profile.rankHistory);
    _education = List.of(profile.education);
    _onlineCourses = List.of(profile.onlineCourses);
    _familyMembers = List.of(profile.familyMembers);
    _awards = List.of(profile.awards);
    _combatParticipation = List.of(profile.combatParticipation);
    _wounds = List.of(profile.wounds);
    _languageSkills = List.of(profile.languageSkills);
  }

  PersonnelProfile _buildProfile() {
    final current = _profile!;
    return current.copyWith(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      patronymic: _patronymicController.text.trim(),
      militaryUnit: _militaryUnitController.text.trim(),
      position: _positionController.text.trim(),
      staffRank: _staffRankController.text.trim(),
      rank: _rankController.text.trim(),
      militarySpecialty: _militarySpecialtyController.text.trim(),
      birthDate: _birthDate,
      phone: _phoneController.text.trim(),
      positionOrderNumber: _positionOrderNumberController.text.trim(),
      positionOrderDate: _positionOrderDate,
      rankHistory: _rankHistory,
      serviceType: _serviceType,
      serviceStartDate: _serviceStartDate,
      contractEndDate: _serviceType == 'contract' ? _contractEndDate : null,
      mobilizationDate: _serviceType == 'mobilization'
          ? _mobilizationDate
          : null,
      relocationReady: _relocationReady,
      education: _education,
      onlineCourses: _onlineCourses,
      familyStatus: _familyStatusController.text.trim(),
      familyMembers: _familyMembers,
      housingStatus: _housingStatusController.text.trim(),
      homeAddress: _homeAddressController.text.trim(),
      currentStatus: _currentStatus,
      rating: _ratingController.text.trim(),
      awards: _awards,
      combatParticipation: _combatParticipation,
      wounds: _wounds,
      languageSkills: _languageSkills,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null || _profile == null) return;

    setState(() => _isSaving = true);
    try {
      final profile = _buildProfile();
      if (_isEditingOwnProfile) {
        await Globals.personnelProfileService.saveOwnProfile(
          groupId: groupId,
          profile: profile,
        );
      } else {
        await Globals.personnelProfileService.saveMemberProfile(
          groupId: groupId,
          uid: profile.uid,
          profile: profile,
        );
      }
      _applyProfile(profile);
      await _loadGroupProfiles();
      Globals.errorNotificationManager.showSuccess(
        'Повну інформацію збережено',
      );
    } catch (e) {
      Globals.errorNotificationManager.showError('Не вдалося зберегти: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportOwnStandard() async {
    if (_profile == null) return;
    await _exportProfiles(
      profiles: [_buildProfile()],
      filenamePrefix: 'Моя_якісна_характеристика',
      groupName: Globals.profileManager.currentGroupName ?? 'Поточна група',
    );
  }

  Future<void> _exportGroupStandard() async {
    final groupName =
        Globals.profileManager.currentGroupName ?? 'Поточна група';
    final profiles = _groupProfiles.isEmpty
        ? [_buildProfile()]
        : _groupProfiles;
    await _exportProfiles(
      profiles: profiles,
      filenamePrefix: 'Якісна_характеристика_$groupName',
      groupName: groupName,
    );
  }

  Future<void> _exportProfiles({
    required List<PersonnelProfile> profiles,
    required String filenamePrefix,
    required String groupName,
  }) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await Globals.personnelProfileService.generateStandardExcel(
        profiles: profiles,
        groupName: groupName,
      );
      final filename = Globals.personnelProfileService.buildExportFilename(
        filenamePrefix,
      );
      await _fileSharer.shareFile(bytes, filename);
    } catch (e) {
      Globals.errorNotificationManager.showError('Помилка експорту: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showCustomExportDialog({
    required List<PersonnelProfile> profiles,
    required String title,
  }) async {
    var columns = List<PersonnelExportColumn>.of(
      PersonnelExportColumn.standard,
    );
    final selected = columns.map((column) => column.key).toSet();

    final result = await showDialog<List<PersonnelExportColumn>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Кастомний експорт'),
              content: SizedBox(
                width: 560,
                height: 520,
                child: ReorderableListView.builder(
                  itemCount: columns.length,
                  onReorder: (oldIndex, newIndex) {
                    setDialogState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = columns.removeAt(oldIndex);
                      columns.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final column = columns[index];
                    return CheckboxListTile(
                      key: ValueKey(column.key),
                      value: selected.contains(column.key),
                      title: Text(column.title),
                      secondary: const Icon(Icons.drag_handle),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selected.add(column.key);
                          } else {
                            selected.remove(column.key);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Скасувати'),
                ),
                FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            columns
                                .where(
                                  (column) => selected.contains(column.key),
                                )
                                .toList(),
                          );
                        },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Експортувати'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final bytes = await Globals.personnelProfileService.generateCustomExcel(
        profiles: profiles,
        columns: result,
        title: title,
      );
      final filename = Globals.personnelProfileService.buildExportFilename(
        title,
      );
      await _fileSharer.shareFile(bytes, filename);
    } catch (e) {
      Globals.errorNotificationManager.showError('Помилка експорту: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final groupId = Globals.profileManager.currentGroupId;
    if (groupId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Спочатку оберіть поточну групу.'),
        ),
      );
    }

    if (_profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Не вдалося підготувати профіль для редагування.'),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const SizedBox(height: 12),
          _buildMainSection(),
          _buildServiceSection(),
          _buildRankSection(),
          _buildEducationSection(),
          _buildFamilySection(),
          _buildExperienceSection(),
          _buildLanguageSection(),
          if (Globals.profileManager.isCurrentGroupAdmin) _buildAdminSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving
                    ? 'Збереження...'
                    : _isEditingOwnProfile
                    ? 'Зберегти повну інформацію'
                    : 'Зберегти профіль учасника',
              ),
            ),
            if (!_isEditingOwnProfile)
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.person),
                label: const Text('Повернутись до мого профілю'),
              ),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportOwnStandard,
              icon: const Icon(Icons.file_download),
              label: Text(
                _isEditingOwnProfile ? 'Експорт мого рядка' : 'Експорт рядка',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () => _showCustomExportDialog(
                      profiles: [_buildProfile()],
                      title: 'Мій кастомний експорт',
                    ),
              icon: const Icon(Icons.view_column),
              label: const Text('Кастомний експорт'),
            ),
            IconButton(
              tooltip: 'Оновити',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSection() {
    return _Section(
      title: 'Основні дані',
      icon: Icons.badge,
      children: [
        _responsiveFields([
          _textField(_lastNameController, 'Прізвище', required: true),
          _textField(_firstNameController, 'Імʼя', required: true),
          _textField(_patronymicController, 'По батькові'),
          _textField(_militaryUnitController, 'В/ч'),
          _textField(_positionController, 'Посада'),
          _textField(_staffRankController, 'ШПК / штатне звання'),
          _textField(_rankController, 'Фактичне звання'),
          _textField(_militarySpecialtyController, 'ВОС'),
          _dateField('Дата народження', _birthDate, (date) {
            setState(() => _birthDate = date);
          }),
          _textField(
            _phoneController,
            'Телефон',
            keyboardType: TextInputType.phone,
          ),
        ]),
      ],
    );
  }

  Widget _buildServiceSection() {
    return _Section(
      title: 'Служба і призначення',
      icon: Icons.assignment_ind,
      children: [
        _responsiveFields([
          _textField(_positionOrderNumberController, '№ наказу призначення'),
          _dateField('Дата наказу призначення', _positionOrderDate, (date) {
            setState(() => _positionOrderDate = date);
          }),
          DropdownButtonFormField<String>(
            value: _serviceType,
            decoration: const InputDecoration(
              labelText: 'Вид військової служби',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'contract', child: Text('За контрактом')),
              DropdownMenuItem(
                value: 'mobilization',
                child: Text('Під час мобілізації'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _serviceType = value);
            },
          ),
          _dateField('З якого року/дати служба', _serviceStartDate, (date) {
            setState(() => _serviceStartDate = date);
          }),
          if (_serviceType == 'contract')
            _dateField('Дія контракту до', _contractEndDate, (date) {
              setState(() => _contractEndDate = date);
            })
          else
            _dateField('Дата призову за мобілізацією', _mobilizationDate, (
              date,
            ) {
              setState(() => _mobilizationDate = date);
            }),
          DropdownButtonFormField<bool>(
            value: _relocationReady,
            decoration: const InputDecoration(
              labelText: 'Готовність до переїзду',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: true, child: Text('Так')),
              DropdownMenuItem(value: false, child: Text('Ні')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _relocationReady = value);
            },
          ),
          DropdownButtonFormField<String>(
            value: _currentStatus,
            decoration: const InputDecoration(
              labelText: 'Місце перебування на даний момент',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'в строю', child: Text('В строю')),
              DropdownMenuItem(value: 'не в строю', child: Text('Не в строю')),
              DropdownMenuItem(value: 'відпустка', child: Text('Відпустка')),
              DropdownMenuItem(value: 'лікарняний', child: Text('Лікарняний')),
              DropdownMenuItem(
                value: 'відрядження',
                child: Text('Відрядження'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _currentStatus = value);
            },
          ),
          _textField(_ratingController, 'Рейтинг'),
        ]),
      ],
    );
  }

  Widget _buildRankSection() {
    return _Section(
      title: 'Історія звань',
      icon: Icons.military_tech,
      action: TextButton.icon(
        onPressed: _addRank,
        icon: const Icon(Icons.add),
        label: const Text('Додати звання'),
      ),
      children: [
        _entryList(
          emptyText: 'Історію звань ще не додано.',
          entries: _rankHistory,
          titleBuilder: (entry) => entry.rank.isEmpty ? 'Звання' : entry.rank,
          subtitleBuilder: (entry) {
            final order = PersonnelProfile.empty(
              uid: '',
              email: '',
            ).copyWith(rankHistory: [entry]).rankOrderText;
            return [
              if (order.isNotEmpty) order,
              if (entry.isCurrent) 'поточне',
            ].join(' • ');
          },
          onEdit: (index) => _editRank(index),
          onDelete: (index) => setState(() => _rankHistory.removeAt(index)),
        ),
      ],
    );
  }

  Widget _buildEducationSection() {
    return _Section(
      title: 'Освіта і курси',
      icon: Icons.school,
      children: [
        _SubsectionHeader(title: 'Освіта', onAdd: _addEducation),
        _entryList(
          emptyText: 'Освіту ще не додано.',
          entries: _education,
          titleBuilder: (entry) => entry.type.isEmpty ? 'Освіта' : entry.type,
          subtitleBuilder: (entry) => entry.summary,
          onEdit: (index) => _editEducation(index),
          onDelete: (index) => setState(() => _education.removeAt(index)),
        ),
        const SizedBox(height: 12),
        _SubsectionHeader(title: 'Онлайн-курси', onAdd: _addOnlineCourse),
        _entryList(
          emptyText: 'Онлайн-курси ще не додано.',
          entries: _onlineCourses,
          titleBuilder: (entry) =>
              entry.topic.isEmpty ? 'Онлайн-курс' : entry.topic,
          subtitleBuilder: (entry) => entry.summary,
          onEdit: (index) => _editOnlineCourse(index),
          onDelete: (index) => setState(() => _onlineCourses.removeAt(index)),
        ),
      ],
    );
  }

  Widget _buildFamilySection() {
    return _Section(
      title: 'Сімʼя, житло і контакти',
      icon: Icons.home_work,
      children: [
        _responsiveFields([
          _textField(_familyStatusController, 'Сімейний стан', maxLines: 2),
          _textField(_housingStatusController, 'Забезпеченість житлом'),
          _textField(_homeAddressController, 'Домашня адреса', maxLines: 2),
        ]),
        const SizedBox(height: 12),
        _SubsectionHeader(title: 'Члени сімʼї', onAdd: _addFamilyMember),
        _entryList(
          emptyText: 'Членів сімʼї ще не додано.',
          entries: _familyMembers,
          titleBuilder: (entry) =>
              entry.relation.isEmpty ? 'Родич' : entry.relation,
          subtitleBuilder: (entry) => entry.summary,
          onEdit: (index) => _editFamilyMember(index),
          onDelete: (index) => setState(() => _familyMembers.removeAt(index)),
        ),
      ],
    );
  }

  Widget _buildExperienceSection() {
    return _Section(
      title: 'Досвід, нагороди, поранення',
      icon: Icons.workspace_premium,
      children: [
        _SubsectionHeader(
          title: 'Державні та відомчі нагороди',
          onAdd: _addAward,
        ),
        _entryList(
          emptyText: 'Нагороди ще не додано.',
          entries: _awards,
          titleBuilder: (entry) => entry.name.isEmpty ? 'Нагорода' : entry.name,
          subtitleBuilder: (entry) => entry.summary,
          onEdit: (index) => _editAward(index),
          onDelete: (index) => setState(() => _awards.removeAt(index)),
        ),
        const SizedBox(height: 12),
        _SubsectionHeader(
          title: 'Безпосередня участь в діях',
          onAdd: _addCombatParticipation,
        ),
        _entryList(
          emptyText: 'Участь в діях ще не додано.',
          entries: _combatParticipation,
          titleBuilder: (entry) =>
              entry.place.isEmpty ? 'Участь в діях' : entry.place,
          subtitleBuilder: (entry) => entry.summary,
          onEdit: (index) => _editCombatParticipation(index),
          onDelete: (index) =>
              setState(() => _combatParticipation.removeAt(index)),
        ),
        const SizedBox(height: 12),
        _SubsectionHeader(title: 'Поранення', onAdd: _addWound),
        _entryList(
          emptyText: 'Поранення ще не додано.',
          entries: _wounds,
          titleBuilder: (entry) =>
              entry.place.isEmpty ? 'Поранення' : entry.place,
          subtitleBuilder: (entry) => entry.summary,
          onEdit: (index) => _editWound(index),
          onDelete: (index) => setState(() => _wounds.removeAt(index)),
        ),
      ],
    );
  }

  Widget _buildLanguageSection() {
    return _Section(
      title: 'Іноземні мови',
      icon: Icons.translate,
      action: TextButton.icon(
        onPressed: _addLanguage,
        icon: const Icon(Icons.add),
        label: const Text('Додати мову'),
      ),
      children: [
        _entryList(
          emptyText: 'Рівні володіння мовами ще не додано.',
          entries: _languageSkills,
          titleBuilder: (entry) =>
              entry.language.isEmpty ? 'Мова' : entry.language,
          subtitleBuilder: (entry) => entry.summary,
          onEdit: (index) => _editLanguage(index),
          onDelete: (index) => setState(() => _languageSkills.removeAt(index)),
        ),
      ],
    );
  }

  Widget _buildAdminSection() {
    final groupName =
        Globals.profileManager.currentGroupName ?? 'Поточна група';
    return _Section(
      title: 'Адмін: профілі групи',
      icon: Icons.admin_panel_settings,
      action: IconButton(
        tooltip: 'Оновити групові профілі',
        onPressed: _isLoadingGroup ? null : _loadGroupProfiles,
        icon: _isLoadingGroup
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportGroupStandard,
              icon: const Icon(Icons.table_chart),
              label: Text('Експорт групи ($groupName)'),
            ),
            OutlinedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () => _showCustomExportDialog(
                      profiles: _groupProfiles.isEmpty
                          ? [_buildProfile()]
                          : _groupProfiles,
                      title: 'Кастомний експорт групи',
                    ),
              icon: const Icon(Icons.view_column),
              label: const Text('Кастомний експорт групи'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_groupProfiles.isEmpty)
          Text(
            'У групі ще немає збережених повних профілів.',
            style: TextStyle(color: AppTheme.textSecondary),
          )
        else
          ..._groupProfiles.map(
            (profile) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(_initials(profile))),
              title: Text(
                profile.fullName.isEmpty ? profile.email : profile.fullName,
              ),
              subtitle: Text(
                [
                  if (profile.currentRankText.isNotEmpty)
                    profile.currentRankText,
                  if (profile.position.isNotEmpty) profile.position,
                  profile.email,
                ].join(' • '),
              ),
              trailing: const Icon(Icons.edit),
              onTap: () {
                setState(() => _applyProfile(profile));
                Globals.errorNotificationManager.showSuccess(
                  'Відкрито повний профіль учасника для редагування',
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => (value?.trim().isEmpty ?? true) ? 'Заповніть поле' : null
          : null,
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (selected != null) onChanged(selected);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(
                  tooltip: 'Очистити',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close),
                ),
              const Icon(Icons.calendar_today),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(value == null ? 'Не вказано' : _dateFormat.format(value)),
      ),
    );
  }

  Widget _responsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 720
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map((field) => SizedBox(width: width, child: field))
              .toList(),
        );
      },
    );
  }

  Widget _entryList<T>({
    required String emptyText,
    required List<T> entries,
    required String Function(T entry) titleBuilder,
    required String Function(T entry) subtitleBuilder,
    required ValueChanged<int> onEdit,
    required ValueChanged<int> onDelete,
  }) {
    if (entries.isEmpty) {
      return Text(emptyText, style: TextStyle(color: AppTheme.textSecondary));
    }

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(titleBuilder(entries[i])),
              subtitle: Text(subtitleBuilder(entries[i])),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Редагувати',
                    onPressed: () => onEdit(i),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Видалити',
                    onPressed: () => onDelete(i),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addRank() async {
    final entry = await _rankDialog();
    if (entry != null) setState(() => _rankHistory.add(entry));
  }

  Future<void> _editRank(int index) async {
    final entry = await _rankDialog(initial: _rankHistory[index]);
    if (entry != null) setState(() => _rankHistory[index] = entry);
  }

  Future<RankHistoryEntry?> _rankDialog({RankHistoryEntry? initial}) async {
    final rank = TextEditingController(text: initial?.rank ?? '');
    final order = TextEditingController(text: initial?.orderNumber ?? '');
    var orderDate = initial?.orderDate;
    var isCurrent = initial?.isCurrent ?? false;

    return _typedDialog<RankHistoryEntry>(
      title: initial == null ? 'Додати звання' : 'Редагувати звання',
      builder: (setDialogState) => [
        _dialogText(rank, 'Звання'),
        _dialogText(order, '№ наказу'),
        _dialogDate('Дата наказу', orderDate, (date) {
          setDialogState(() => orderDate = date);
        }),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: isCurrent,
          title: const Text('Поточне звання'),
          onChanged: (value) =>
              setDialogState(() => isCurrent = value ?? false),
        ),
      ],
      onSubmit: () => RankHistoryEntry(
        rank: rank.text.trim(),
        orderNumber: order.text.trim(),
        orderDate: orderDate,
        isCurrent: isCurrent,
      ),
    );
  }

  Future<void> _addEducation() async {
    final entry = await _educationDialog();
    if (entry != null) setState(() => _education.add(entry));
  }

  Future<void> _editEducation(int index) async {
    final entry = await _educationDialog(initial: _education[index]);
    if (entry != null) setState(() => _education[index] = entry);
  }

  Future<EducationEntry?> _educationDialog({EducationEntry? initial}) async {
    final type = TextEditingController(text: initial?.type ?? '');
    final institution = TextEditingController(text: initial?.institution ?? '');
    final specialty = TextEditingController(text: initial?.specialty ?? '');
    final degree = TextEditingController(text: initial?.degree ?? '');
    final year = TextEditingController(text: initial?.year ?? '');
    final notes = TextEditingController(text: initial?.notes ?? '');

    return _typedDialog<EducationEntry>(
      title: initial == null ? 'Додати освіту' : 'Редагувати освіту',
      builder: (_) => [
        _dialogDropdownText(
          controller: type,
          label: 'Тип',
          options: const [
            'середня',
            'вища',
            'військова',
            'КПК',
            'КВПО',
            'курси',
          ],
        ),
        _dialogText(institution, 'Навчальний заклад'),
        _dialogText(specialty, 'Спеціальність'),
        _dialogText(degree, 'Ступінь / рівень'),
        _dialogText(year, 'Рік'),
        _dialogText(notes, 'Примітки', maxLines: 2),
      ],
      onSubmit: () => EducationEntry(
        type: type.text.trim(),
        institution: institution.text.trim(),
        specialty: specialty.text.trim(),
        degree: degree.text.trim(),
        year: year.text.trim(),
        notes: notes.text.trim(),
      ),
    );
  }

  Future<void> _addOnlineCourse() async {
    final entry = await _onlineCourseDialog();
    if (entry != null) setState(() => _onlineCourses.add(entry));
  }

  Future<void> _editOnlineCourse(int index) async {
    final entry = await _onlineCourseDialog(initial: _onlineCourses[index]);
    if (entry != null) setState(() => _onlineCourses[index] = entry);
  }

  Future<OnlineCourseEntry?> _onlineCourseDialog({
    OnlineCourseEntry? initial,
  }) async {
    final topic = TextEditingController(text: initial?.topic ?? '');
    final cert = TextEditingController(text: initial?.certificateNumber ?? '');
    var date = initial?.date;

    return _typedDialog<OnlineCourseEntry>(
      title: initial == null ? 'Додати онлайн-курс' : 'Редагувати онлайн-курс',
      builder: (setDialogState) => [
        _dialogText(topic, 'Тематика'),
        _dialogDate('Дата сертифікату', date, (value) {
          setDialogState(() => date = value);
        }),
        _dialogText(cert, '№ сертифікату'),
      ],
      onSubmit: () => OnlineCourseEntry(
        topic: topic.text.trim(),
        date: date,
        certificateNumber: cert.text.trim(),
      ),
    );
  }

  Future<void> _addFamilyMember() async {
    final entry = await _familyDialog();
    if (entry != null) setState(() => _familyMembers.add(entry));
  }

  Future<void> _editFamilyMember(int index) async {
    final entry = await _familyDialog(initial: _familyMembers[index]);
    if (entry != null) setState(() => _familyMembers[index] = entry);
  }

  Future<FamilyMemberEntry?> _familyDialog({FamilyMemberEntry? initial}) async {
    final relation = TextEditingController(text: initial?.relation ?? '');
    final fullName = TextEditingController(text: initial?.fullName ?? '');
    final profession = TextEditingController(text: initial?.profession ?? '');
    final address = TextEditingController(text: initial?.address ?? '');
    final phone = TextEditingController(text: initial?.phone ?? '');
    var birthDate = initial?.birthDate;

    return _typedDialog<FamilyMemberEntry>(
      title: initial == null ? 'Додати члена сімʼї' : 'Редагувати члена сімʼї',
      builder: (setDialogState) => [
        _dialogText(relation, 'Родинний звʼязок'),
        _dialogText(fullName, 'ПІБ'),
        _dialogDate('Дата народження', birthDate, (value) {
          setDialogState(() => birthDate = value);
        }),
        _dialogText(profession, 'Професія'),
        _dialogText(address, 'Місце проживання'),
        _dialogText(phone, 'Телефон'),
      ],
      onSubmit: () => FamilyMemberEntry(
        relation: relation.text.trim(),
        fullName: fullName.text.trim(),
        birthDate: birthDate,
        profession: profession.text.trim(),
        address: address.text.trim(),
        phone: phone.text.trim(),
      ),
    );
  }

  Future<void> _addAward() async {
    final entry = await _awardDialog();
    if (entry != null) setState(() => _awards.add(entry));
  }

  Future<void> _editAward(int index) async {
    final entry = await _awardDialog(initial: _awards[index]);
    if (entry != null) setState(() => _awards[index] = entry);
  }

  Future<AwardEntry?> _awardDialog({AwardEntry? initial}) async {
    final name = TextEditingController(text: initial?.name ?? '');
    final order = TextEditingController(text: initial?.orderNumber ?? '');
    var date = initial?.date;

    return _typedDialog<AwardEntry>(
      title: initial == null ? 'Додати нагороду' : 'Редагувати нагороду',
      builder: (setDialogState) => [
        _dialogText(name, 'Назва'),
        _dialogText(order, '№ наказу / нагороди'),
        _dialogDate(
          'Дата',
          date,
          (value) => setDialogState(() => date = value),
        ),
      ],
      onSubmit: () => AwardEntry(
        name: name.text.trim(),
        orderNumber: order.text.trim(),
        date: date,
      ),
    );
  }

  Future<void> _addCombatParticipation() async {
    final entry = await _eventDialog(title: 'Додати участь в діях');
    if (entry != null) setState(() => _combatParticipation.add(entry));
  }

  Future<void> _editCombatParticipation(int index) async {
    final entry = await _eventDialog(
      title: 'Редагувати участь в діях',
      initial: _combatParticipation[index],
    );
    if (entry != null) setState(() => _combatParticipation[index] = entry);
  }

  Future<void> _addWound() async {
    final entry = await _eventDialog(title: 'Додати поранення');
    if (entry != null) setState(() => _wounds.add(entry));
  }

  Future<void> _editWound(int index) async {
    final entry = await _eventDialog(
      title: 'Редагувати поранення',
      initial: _wounds[index],
    );
    if (entry != null) setState(() => _wounds[index] = entry);
  }

  Future<EventHistoryEntry?> _eventDialog({
    required String title,
    EventHistoryEntry? initial,
  }) async {
    final time = TextEditingController(text: initial?.time ?? '');
    final place = TextEditingController(text: initial?.place ?? '');
    final circumstances = TextEditingController(
      text: initial?.circumstances ?? '',
    );
    var startDate = initial?.startDate;
    var endDate = initial?.endDate;

    return _typedDialog<EventHistoryEntry>(
      title: title,
      builder: (setDialogState) => [
        _dialogDate('Дата початку', startDate, (value) {
          setDialogState(() => startDate = value);
        }),
        _dialogDate('Дата завершення', endDate, (value) {
          setDialogState(() => endDate = value);
        }),
        _dialogText(time, 'Час'),
        _dialogText(place, 'Місце'),
        _dialogText(circumstances, 'Обставини', maxLines: 3),
      ],
      onSubmit: () => EventHistoryEntry(
        startDate: startDate,
        endDate: endDate,
        time: time.text.trim(),
        place: place.text.trim(),
        circumstances: circumstances.text.trim(),
      ),
    );
  }

  Future<void> _addLanguage() async {
    final entry = await _languageDialog();
    if (entry != null) setState(() => _languageSkills.add(entry));
  }

  Future<void> _editLanguage(int index) async {
    final entry = await _languageDialog(initial: _languageSkills[index]);
    if (entry != null) setState(() => _languageSkills[index] = entry);
  }

  Future<LanguageSkillEntry?> _languageDialog({
    LanguageSkillEntry? initial,
  }) async {
    final language = TextEditingController(text: initial?.language ?? '');
    var civilian = initial?.civilianLevel ?? '';
    var military = initial?.militaryLevel ?? '';

    return _typedDialog<LanguageSkillEntry>(
      title: initial == null ? 'Додати мову' : 'Редагувати мову',
      builder: (setDialogState) => [
        _dialogText(language, 'Мова'),
        DropdownButtonFormField<String>(
          value: civilian.isEmpty ? null : civilian,
          decoration: const InputDecoration(
            labelText: 'Цивільний рівень',
            border: OutlineInputBorder(),
          ),
          items: const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setDialogState(() => civilian = value ?? ''),
        ),
        DropdownButtonFormField<String>(
          value: military.isEmpty ? null : military,
          decoration: const InputDecoration(
            labelText: 'Військовий рівень',
            border: OutlineInputBorder(),
          ),
          items: const ['СМР-0', 'СМР-1', 'СМР-2', 'СМР-3', 'СМР-4', 'СМР-5+']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setDialogState(() => military = value ?? ''),
        ),
      ],
      onSubmit: () => LanguageSkillEntry(
        language: language.text.trim(),
        civilianLevel: civilian,
        militaryLevel: military,
      ),
    );
  }

  Future<T?> _typedDialog<T>({
    required String title,
    required List<Widget> Function(StateSetter setDialogState) builder,
    required T Function() onSubmit,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final child in builder(setDialogState))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: child,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Скасувати'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(onSubmit()),
                child: const Text('Зберегти'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dialogText(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _dialogDropdownText({
    required TextEditingController controller,
    required String label,
    required List<String> options,
  }) {
    final values = {
      ...options,
      if (controller.text.isNotEmpty) controller.text,
    }.toList();
    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty ? null : controller.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (value) => controller.text = value ?? '',
    );
  }

  Widget _dialogDate(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return _dateField(label, value, onChanged);
  }

  String _initials(PersonnelProfile profile) {
    final name = profile.fullName.trim();
    if (name.isEmpty)
      return profile.email.isEmpty ? '?' : profile.email[0].toUpperCase();
    return name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.action,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: action == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [action!, const Icon(Icons.expand_more)],
              ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }
}

class _SubsectionHeader extends StatelessWidget {
  const _SubsectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Додати'),
        ),
      ],
    );
  }
}
