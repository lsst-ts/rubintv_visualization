import 'dart:convert';

/// A command to be sent to the analysis service.
class ServiceCommand {
  /// The name of hte command
  String name;

  /// The parameters of the command.
  Map<String, dynamic> parameters;

  ServiceCommand(this.name, this.parameters);

  /// Convert the command to a JSON formatted string.
  String toJson() => jsonEncode({"name": name, "parameters": parameters});
}

class LoadSchemaCommand extends ServiceCommand {
  LoadSchemaCommand()
      : super("load schema", {
          "database": "summitcdb",
        });
}
