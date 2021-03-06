use NativeCall;
use SDL2::Raw;
use Cairo;

constant W = 1280;
constant H = 960;

constant FIELDW = W div 32;
constant FIELDH = H div 32;

SDL_Init(VIDEO);

my CArray[SDL_Window] $pass_win .= new;
my CArray[SDL_Renderer] $pass_render .= new;

$pass_win[0] = SDL_Window;
$pass_render[0] = SDL_Renderer;

say SDL_CreateWindowAndRenderer(W, H, 2, $pass_win, $pass_render);

my $window = $pass_win[0];
my $render = $pass_render[0];

my $snake_image = Cairo::Image.record(
    -> $_ {
        .save;
        .rectangle: 0, 0, 64, 64;
        .clip;
        .rgb: 0, 1, 0;
        .rectangle: 0, 0, 64, 64;
        .fill :preserve;
        .rgb: 0, 0, 0;
        .stroke;
        .restore;

        .save;
        .translate: 64, 0;
        .rectangle: 0, 0, 64, 64;
        .clip;
        .rgb: 1, 0, 0;
        .arc: 32, 32, 30, 0, 2 * pi;
        .fill :preserve;
        .rgb: 0, 0, 0;
        .stroke;
        .restore;
    }, 128, 128, FORMAT_ARGB32);

my $snake_texture = SDL_CreateTexture($render, %PIXELFORMAT<ARGB8888>, STATIC, 128, 128);
SDL_UpdateTexture($snake_texture, SDL_Rect.new(:x(0), :y(0), :w(128), :h(128)), $snake_image.data, $snake_image.stride // 128 * 4);
SDL_SetTextureBlendMode($snake_texture, 1);

SDL_SetRenderDrawBlendMode($render, 1);

my $snakepiece_srcrect = SDL_Rect.new(:w(64), :h(64));
my $foodpiece_srcrect = SDL_Rect.new(:x(64), :w(64), :h(64));

my @times;

my num $start = nqp::time_n();
my $event = SDL_Event.new;

enum GAME_KEYS (
    K_UP    => 82,
    K_DOWN  => 81,
    K_LEFT  => 80,
    K_RIGHT => 79,
    K_SPACE => 44,
);

my %down_keys;

my Complex @snakepieces = 10 + 10i;
my Complex @noms;
my $nomspawn  = 0;
my $snakespeed = 0.1;
my $snakestep = 0;
my Complex $snakedir = 1+0i;
my $nom = 4;

my num $last_frame_start = nqp::time_n();
main: loop {
    my num $start = nqp::time_n();
    my $dt = $start - $last_frame_start // 0.00001;
    while SDL_PollEvent($event) {
        my $casted_event = SDL_CastEvent($event);

        given $casted_event {
            when *.type == QUIT {
                last main;
            }
            when *.type == KEYDOWN {
                if GAME_KEYS(.scancode) -> $comm {
                    %down_keys{$comm} = 1;
                } else { say "new keycode found: $_.scancode()"; }

                CATCH { say $_ }
            }
            when *.type == KEYUP {
                if GAME_KEYS(.scancode) -> $comm {
                    %down_keys{$comm} = 0;
                } else { say "new keycode found: $_.scancode()"; }

                CATCH { say $_ }
            }
        }
    }

    if %down_keys<K_LEFT> {
        $snakedir = -1+0i unless $snakedir == 1+0i;
    } elsif %down_keys<K_RIGHT> {
        $snakedir = 1+0i  unless $snakedir == -1+0i;
    } elsif %down_keys<K_UP> {
        $snakedir = 0-1i unless $snakedir == 0+1i;
    } elsif %down_keys<K_DOWN> {
        $snakedir = 0+1i unless $snakedir == 0-1i;
    }

    if ($nomspawn -= $dt) < 0 {
        $nomspawn += 1;
        @noms.push: (^FIELDW).pick + (^FIELDH).pick * i unless @noms > 3;
        @noms.pop if @noms[*-1] == any(@snakepieces);
    }

    if ($snakestep -= $dt) < 0 {
        $snakestep += $snakespeed;

        @snakepieces.unshift: do given @snakepieces[0] {
            ($_.re + $snakedir.re) % FIELDW
            + (($_.im + $snakedir.im) % FIELDH) * i
        }

        #@snakepieces.unshift: @snakepieces[0] + $snakedir;


        if @snakepieces[2..*].first-index({ $_ == @snakepieces[0] }) -> $idx {
            @snakepieces = @snakepieces[0..($idx + 1)];
        }

        @noms .= grep({
                $^piece == @snakepieces[0] ?? ($nom += 1) && False
                                           !! True
            });

        if $nom == 0 {
            @snakepieces.pop;
        } else {
            $nom = $nom - 1;
        }
    }

    for @snakepieces {
        SDL_SetTextureColorMod($snake_texture, 255, (cos((++$) / 2) * 100 + 155).round, 255);
        SDL_RenderCopy($render, $snake_texture,
            $snakepiece_srcrect,
            SDL_Rect.new(:x(.re.Int * 32), :y(.im.Int * 32), :w(32), :h(32)));
    }
    SDL_SetTextureColorMod($snake_texture, 255, 255, 255);
    for @noms {
        SDL_RenderCopy($render, $snake_texture,
            $foodpiece_srcrect,
            SDL_Rect.new(:x(.re.Int * 32), :y(.im.Int * 32), :w(32), :h(32)));
    }

    SDL_RenderPresent($render);
    SDL_SetRenderDrawColor($render, 0, 0, 0, 0);
    SDL_RenderClear($render);

    nqp::force_gc() if 5.rand < 1;

    @times.push: nqp::time_n() - $start;

    $last_frame_start = $start;
    sleep(1 / 50);
}

SDL_Quit();

@times .= sort;

my @timings = (@times[* div 50], @times[* div 4], @times[* div 2], @times[* * 3 div 4], @times[* - * div 100]);

say "frames per second:";
say (1 X/ @timings).fmt("%3.4f");
say "timings:";
say (     @timings).fmt("%3.4f");
say "";
