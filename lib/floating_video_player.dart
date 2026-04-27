// Models
export 'src/models/floating_state.dart';
export 'src/models/video_source.dart';

// Controller & provider
export 'src/controller/floating_view_controller.dart'
    show
        FloatingViewController,
        FloatingViewProvider,
        FloatingViewX,
        ViewportInsets,
        PlayerControlsBuilder;

// Player widgets
export 'src/player/floating_player_view.dart'
    show FloatingPlayerView, FloatingPlayerViewState;
export 'src/player/widgets/player_controls.dart'
    show PlayerControls, PlayerControlsState;
export 'src/player/widgets/circle_button.dart';
export 'src/player/widgets/video_seek_bar.dart';

// Back-button integration
export 'src/gestures/player_animation_mixin.dart' show handleFloatingWillPop;
