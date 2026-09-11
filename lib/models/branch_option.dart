class BranchOption {
  const BranchOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  String get label => name.isNotEmpty ? name : code;

  factory BranchOption.fromJson(Map<String, dynamic> json) {
    final code = (json['Code'] ??
            json['code'] ??
            json['Branch'] ??
            json['branch'] ??
            json['branchCode'] ??
            json['Id'] ??
            json['id'] ??
            json['WaiterCode'] ??
            json['waiterCode'] ??
            '')
        .toString()
        .trim();
    final name = (json['Name'] ??
            json['name'] ??
            json['BranchName'] ??
            json['branchName'] ??
            json['Waiter'] ??
            json['waiter'] ??
            json['WaiterName'] ??
            json['waiterName'] ??
            json['Description'] ??
            json['description'] ??
            code)
        .toString()
        .trim();
    return BranchOption(
      code: code.isNotEmpty ? code : name,
      name: name.isNotEmpty ? name : code,
    );
  }
}
