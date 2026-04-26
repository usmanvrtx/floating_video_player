// Models
export 'src/models/floating_state.dart';

// Controller & provider
export 'src/controller/floating_view_controller.dart'
    show
        FloatingViewController,
        FloatingViewProvider,
        FloatingViewX,
        ViewportInsets;

// Player widgets
export 'src/player/floating_player_view.dart'
    show FloatingPlayerView, FloatingPlayerViewState, SlideAnimationCallback;
export 'src/player/player_view.dart' show PlayerView, PlayerViewState;
export 'src/player/widgets/custom_player_controls.dart'
    show CustomPlayerControls, CustomPlayerControlsState;
export 'src/player/widgets/circle_button.dart';
export 'src/player/widgets/video_seek_bar.dart';

// Overlay management
export 'src/overlay/overlay_stack_manager.dart';

// Gesture system
export 'src/gestures/player_animation_mixin.dart'
    show PlayerAnimationMixin, handleFloatingWillPop;
