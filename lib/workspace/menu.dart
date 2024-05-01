import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:menu_bar/menu_bar.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/chart.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// Notify the user that functionality has not yet been implemented
VoidCallback showNotImplemented(BuildContext context) {
  return () {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
            child: Padding(
          padding: const EdgeInsets.all(20),
          child: IntrinsicHeight(
            child: Column(children: [
              const Text("This button is not yet implemented!"),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("ok"),
              ),
            ]),
          ),
        ));
      },
    );
  };
}

/// Add a new [CartesianPlot] to the [WorkspaceViewer].
class CreateNewChartAction extends UiAction {
  final InteractiveChartTypes chartType;
  final AppTheme theme;

  CreateNewChartAction({
    this.chartType = InteractiveChartTypes.cartesianScatter,
    required this.theme,
  });
}

class DataSetSelectorDialog extends StatelessWidget {
  final AppTheme theme;
  final DataCenter dataCenter;

  const DataSetSelectorDialog({
    super.key,
    required this.theme,
    required this.dataCenter,
  });

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String>> dataSetEntries = dataCenter.databases.keys
        .map((String name) => DropdownMenuItem(value: name, child: Text(name)))
        .toList();

    return Dialog(
      child: IntrinsicWidth(
        child: DropdownButtonFormField<String>(
          items: dataSetEntries,
          decoration: theme.queryTextDecoration.copyWith(
            labelText: "data set",
          ),
          onChanged: (String? dataSetName) {
            Navigator.pop(context, dataSetName);
          },
        ),
      ),
    );
  }
}

class AppMenu extends StatelessWidget {
  final Widget child;
  final AppTheme theme;
  final DispatchAction dispatch;
  final DataCenter dataCenter;

  const AppMenu({
    super.key,
    required this.theme,
    required this.child,
    required this.dispatch,
    required this.dataCenter,
  });

  Future<String?> _selectDataSet(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => DataSetSelectorDialog(
        theme: theme,
        dataCenter: dataCenter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuBarWidget(
      // Style the menu bar itself. Hover over [MenuStyle] for all the options
      barStyle: const MenuStyle(
        padding: MaterialStatePropertyAll(EdgeInsets.zero),
        backgroundColor: MaterialStatePropertyAll(Color(0xFF2b2b2b)),
        maximumSize: MaterialStatePropertyAll(Size(double.infinity, 28.0)),
      ),

      // Style the menu bar buttons. Hover over [ButtonStyle] for all the options
      barButtonStyle: const ButtonStyle(
        padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 6.0)),
        minimumSize: MaterialStatePropertyAll(Size(0.0, 32.0)),
      ),

      // Style the menu and submenu buttons. Hover over [ButtonStyle] for all the options
      menuButtonStyle: const ButtonStyle(
        minimumSize: MaterialStatePropertyAll(Size.fromHeight(36.0)),
        padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0)),
      ),

      // Enable or disable the bar
      enabled: true,

      barButtons: [
        BarButton(
          text: const Text(
            'File',
            style: TextStyle(color: Colors.white),
          ),
          submenu: SubMenu(
            menuItems: [
              MenuButton(
                onTap: showNotImplemented(context),
                text: const Text('Save Workspace'),
                shortcutText: 'Ctrl+S',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
              ),
              MenuButton(
                onTap: showNotImplemented(context),
                text: const Text('Save Workspace as'),
                shortcutText: 'Ctrl+Shift+S',
              ),
              const MenuDivider(),
              MenuButton(
                onTap: showNotImplemented(context),
                text: const Text('Open Workspace'),
              ),
              const MenuDivider(),
              MenuButton(
                text: const Text('Preferences'),
                icon: const Icon(Icons.settings),
                submenu: SubMenu(
                  menuItems: [
                    MenuButton(
                      onTap: showNotImplemented(context),
                      icon: const Icon(Icons.keyboard),
                      text: const Text('Shortcuts'),
                    ),
                    const MenuDivider(),
                    MenuButton(
                      onTap: showNotImplemented(context),
                      icon: const Icon(Icons.extension),
                      text: const Text('Extensions'),
                    ),
                    const MenuDivider(),
                    MenuButton(
                      icon: const Icon(Icons.looks),
                      text: const Text('Change theme'),
                      submenu: SubMenu(
                        menuItems: [
                          MenuButton(
                            onTap: showNotImplemented(context),
                            icon: const Icon(Icons.light_mode),
                            text: const Text('Light theme'),
                          ),
                          const MenuDivider(),
                          MenuButton(
                            onTap: showNotImplemented(context),
                            icon: const Icon(Icons.dark_mode),
                            text: const Text('Dark theme'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const MenuDivider(),
              MenuButton(
                onTap: showNotImplemented(context),
                shortcutText: 'Ctrl+Q',
                text: const Text('Exit'),
                icon: const Icon(Icons.exit_to_app),
              ),
            ],
          ),
        ),
        BarButton(
          text: const Text(
            'Edit',
            style: TextStyle(color: Colors.white),
          ),
          submenu: SubMenu(
            menuItems: [
              MenuButton(
                onTap: () {},
                text: const Text('Undo'),
                shortcutText: 'Ctrl+Z',
              ),
              MenuButton(
                onTap: () {},
                text: const Text('Redo'),
                shortcutText: 'Ctrl+Y',
              ),
              const MenuDivider(),
              MenuButton(
                onTap: () {},
                text: const Text('Cut'),
                shortcutText: 'Ctrl+X',
              ),
              MenuButton(
                onTap: () {},
                text: const Text('Copy'),
                shortcutText: 'Ctrl+C',
              ),
              MenuButton(
                onTap: () {},
                text: const Text('Paste'),
                shortcutText: 'Ctrl+V',
              ),
              const MenuDivider(),
              MenuButton(
                onTap: () {},
                text: const Text('Find'),
                shortcutText: 'Ctrl+F',
              ),
            ],
          ),
        ),
        BarButton(
          text: const Text(
            'Plotting',
            style: TextStyle(color: Colors.white),
          ),
          submenu: SubMenu(
            menuItems: [
              MenuButton(
                text: const Text("New"),
                submenu: SubMenu(menuItems: [
                  MenuButton(
                    onTap: () {
                      dispatch(CreateNewChartAction(
                        chartType: InteractiveChartTypes.cartesianScatter,
                        theme: theme,
                      ));
                    },
                    text: const Text("Cartesian Scatter Plot"),
                  ),
                  MenuButton(
                    onTap: () {
                      dispatch(CreateNewChartAction(
                        chartType: InteractiveChartTypes.polarScatter,
                        theme: theme,
                      ));
                    },
                    text: const Text("Polar Scatter Plot"),
                  ),
                  MenuButton(
                    onTap: () {
                      dispatch(CreateNewChartAction(
                        chartType: InteractiveChartTypes.histogram,
                        theme: theme,
                      ));
                    },
                    text: const Text("Histogram"),
                  ),
                  MenuButton(
                    onTap: () {
                      dispatch(CreateNewChartAction(
                        chartType: InteractiveChartTypes.box,
                        theme: theme,
                      ));
                    },
                    text: const Text("Box Chart"),
                  ),
                ]),
              ),
            ],
          ),
        ),
        BarButton(
          text: const Text(
            'Help',
            style: TextStyle(color: Colors.white),
          ),
          submenu: SubMenu(
            menuItems: [
              MenuButton(
                onTap: showNotImplemented(context),
                text: const Text('Check for updates'),
              ),
              const MenuDivider(),
              MenuButton(
                onTap: showNotImplemented(context),
                text: const Text('View License'),
              ),
              const MenuDivider(),
              MenuButton(
                onTap: showNotImplemented(context),
                icon: const Icon(Icons.info),
                text: const Text('About'),
              ),
            ],
          ),
        ),
      ],

      // Set the child, i.e. the application under the menu bar
      child: child,
    );
  }
}
