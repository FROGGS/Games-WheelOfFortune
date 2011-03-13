#!perl

use strict;
use warnings;

use List::Util qw(shuffle);
use Text::Wrap qw(wrap);
use Time::HiRes;

use SDL;
use SDL::Events;
use SDL::Mouse;
use SDL::Video;
use SDL::VideoInfo;
use SDL::Surface;
use SDLx::App;
use SDLx::Surface;
use SDLx::Text;

# initializing video and retrieving current video resolution
SDL::init(SDL_INIT_VIDEO);
my $video_info           = SDL::Video::get_video_info();
my $screen_w             = $video_info->current_w;
my $screen_h             = $video_info->current_h;
$ENV{SDL_VIDEO_CENTERED} = 'center';
my $app                  = SDLx::App->new( width => $screen_w, height => $screen_h,
                                           depth => 32, title => "Wheel Of Fortune", color => 0x000000FF,
                                           flags => SDL_SWSURFACE|SDL_DOUBLEBUF|SDL_NOFRAME, eoq => 1 );
my $last_click           = Time::HiRes::time;
$Text::Wrap::columns     = 12;

# ingame states
my $lives           =  5;
my $time_per_round  = 60; # constant
my $round_started   =  0; # timestamp
my $points          =  0;
my $points_per_char = 15; # constant
my $current_genre   = '';
my $current_quest   = '';
my $chosen_chars    = '';
my @quests_done     = ();

my $label;                # SDLx::Text object for labels
my $char;                 # SDLx::Text object for quest and alphabet
my $char_W_w;             # width in pixels of char 'W'
my @controls        = (); # list of controls
my @data            = <DATA>;

run_app();

sub run_app {
    $label    = SDLx::Text->new( color => [ 255, 255, 255 ], size => sqrt($app->w * $app->h) / 30, h_align => 'left' );
    $char     = SDLx::Text->new( color => [ 255, 255, 255 ], size => sqrt($app->w * $app->h) / 15, h_align => 'center', text => 'W');
    $char_W_w = $char->w;
    @controls = ();

    # drawing labels
    $label->write_xy($app, _x(8) - $char_W_w / 2, _y(10), 'Round');
    $label->write_xy($app, _x(8) - $char_W_w / 2, _y(20), 'Points');
    $label->write_xy($app, _x(8) - $char_W_w / 2, _y(30), 'Lives');
    #$label->write_xy($app, _x(8) - $char_W_w / 2, _y(40), 'Time remaining');
    
    _next_round();
    _draw_stats();
    _draw_chars();
    _draw_quest();
    
    $app->add_show_handler(  sub { $app->update } );
    $app->add_event_handler( sub {
        my $e = shift;
        
        if($e->type == SDL_KEYDOWN && $e->key_sym == SDLK_ESCAPE) {
            $app->stop;
        }
        
        # double click will toggle between fullscreen and windowed mode
        elsif ($e->type == SDL_MOUSEBUTTONDOWN && $e->button_button == SDL_BUTTON_LEFT) {
            my $time = Time::HiRes::time;
            if ($time - $last_click < 0.3) {
                $app->stop;
                SDL::quit;
                $ENV{SDL_VIDEO_CENTERED} = $app->w == $screen_w ? undef : 'center';
                $app = SDLx::App->new( width  => $app->w == $screen_w ? $screen_w * 0.8 : $screen_w,
                                       height => $app->h == $screen_h ? $screen_h * 0.8 : $screen_h,
                                       depth => 32, title => "Wheel Of Fortune", color => 0x000000FF,
                                       flags => SDL_HWSURFACE|SDL_DOUBLEBUF| ($app->w == $screen_w ? SDL_RESIZABLE : SDL_NOFRAME),
                                       eoq => 1 );
                run_app();
            }
            else {
                for(@controls) {
                    if($_->[0] < $e->button_x && $e->button_x < $_->[2]
                    && $_->[1] < $e->button_y && $e->button_y < $_->[3]) {
                        if($current_quest !~ /\Q$_->[4]\E/ && $chosen_chars !~ /\Q$_->[4]\E/) {
                            $lives--;
                            unless($lives) {
                                printf("Your Score:\n  Round:  %4d\n  Points: %4d\n", $#quests_done + 1, $points);
                                $app->stop;
                            }
                        }
                        
                        $chosen_chars .= $_->[4];
                        my $quest_done = 1;
                        for(split(//, $current_quest)) {
                            next if /\s/;
                            
                            if($chosen_chars !~ /\Q$_\E/) {
                                $quest_done = 0;
                                last;
                            }
                        }
                        _next_round() if $quest_done;
                        _draw_stats();
                        _draw_quest();
                        _draw_chars();
                        last;
                    }
                }
            }
            $last_click = $time;
        }

        # window resizing
        elsif ($e->type == SDL_VIDEORESIZE) {
            $app->stop;
            SDL::quit;
            $app = SDLx::App->new( width => $e->resize_w, height => $e->resize_h,
                                   depth => 32, title => "Wheel Of Fortune", color => 0x000000FF,
                                   flags => SDL_HWSURFACE|SDL_DOUBLEBUF|SDL_RESIZABLE, eoq => 1 );
            run_app();
        }
    } );
    $app->run();
}

sub _x {
    return ($app->w * shift) / 100;
}

sub _y {
    return ($app->h * shift) / 100;
}

sub _next_round()
{
    if(scalar @quests_done) {
        $points += length($current_quest) * $points_per_char;
        $lives++ if $lives < 5;
    }
    
    my @available_quests = ();
    @quests_done         = () if $#quests_done == $#data;
    
    for my $quest (0..$#data) {
        my $quest_done = 0;
        for(@quests_done) {
            if($_ == $quest) {
                $quest_done = 1;
                last;
            }
        }
        
        push(@available_quests, $quest) unless $quest_done;
    }
    
    my $index      = shuffle(@available_quests);
    ($current_genre, $current_quest) = split(/:/, $data[$index]);
    $current_quest = uc($current_quest);
    $chosen_chars  = '';
    push(@quests_done, $index);
}

sub _draw_stats {
    $app->draw_rect([_x(8) - $char_W_w / 2, _y(15), _x(20), $label->h], 0x000000FF);
    $app->draw_rect([_x(8) - $char_W_w / 2, _y(25), _x(20), $label->h], 0x000000FF);
    $app->draw_rect([_x(8) - $char_W_w / 2, _y(35), _x(20), $label->h], 0x000000FF);
    #$app->draw_rect([_x(8) - $char_W_w / 2, _y(45), _x(20), $label->h], 0x000000FF);
    
    $label->write_xy($app, _x(8) - $char_W_w / 2, _y(15), $#quests_done + 1);
    $label->write_xy($app, _x(8) - $char_W_w / 2, _y(25), $points);
    $label->write_xy($app, _x(8) - $char_W_w / 2, _y(35), $lives);
    #$label->write_xy($app, _x(8) - $char_W_w / 2, _y(45), $time_per_round);
}

sub _draw_chars {
    for(0..12) {
        my $x = _x(8 + $_ * 7);
        for my $y (0..1) {
            my $c = $y ? chr( ord('N') + $_ ) : chr( ord('A') + $_ );
            $y    = $y ? _y(80)         : _y(65);
            
            $app->draw_rect([$x - $char_W_w / 2, $y, $char_W_w, $char->h], 0x777777FF);
            $char->write_xy($app, $x, $y, $c);
            
            if($chosen_chars =~ /\Q$c\E/) {
                $app->draw_rect([$x - $char_W_w / 2, $y, $char_W_w, $char->h], 0x000000CC);
            }

            push(@controls, [$x - $char_W_w / 2, $y,
                             $x + $char_W_w / 2, $y + $char->h, $c]);
        }
    }
}

sub _draw_quest {
    $app->draw_rect([_x(29), _y(5), _x(100), $label->h], 0x000000FF);
    $label->h_align('center');
    $label->write_xy($app, _x(50), _y(5), "Genre: $current_genre");
    $label->h_align('left');

    my @lines = split(/[\r\n]/ , wrap('', '', $current_quest));

    for(0..$#lines) {
        # padding the string
        $lines[$_] = (0 x ((12 - length($lines[$_])) / 2)) . $lines[$_];
        
        # replacing whitespaces
        $lines[$_] =~ s/\s/0/g;
        
        my @chars  = split(//, $lines[$_]);
        $lines[$_] = \@chars;
    }
    
    if($#lines < 3) {
        unshift(@lines, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    }
    
    for(0..11) {
        my $x = _x(29 + $_ * 5.72);
        for my $line (0..3) {
            $app->draw_rect([$x - $char_W_w / 2, _y(10 + 12 * $line), $char_W_w, $char->h], $lines[$line]->[$_] ? 0xCCCCCCFF : 0x773377FF);

            if($lines[$line]->[$_] && $chosen_chars =~ /\Q$lines[$line]->[$_]\E/) {
                $char->write_xy($app, $x, _y(10 + 12 * $line), $lines[$line]->[$_]);
            }
        }
    }
}

__DATA__
Actor:Patrick Stewart
Actor:Jonathan Frakes
Actor:LeVar Burton
Actor:Marina Sirtis
Actor:Brent Spiner
Actor:Michael Dorn
Actor:Gates McFadden
Actor:Majel Barrett
Actor:Wil Wheaton
Actor:Colm Meaney
Actor:Denise Crosby
Actor:Whoopi Goldberg
Actor:John de Lancie
Actor:Dwight Schultz
Idiom:Long Time No See
Idiom:A bird in the hand is worth two in the bush
Idiom:Bite off more than you can chew
Idiom:Close but no cigar
Idiom:Coals to Newcastle
Idiom:Dressed to the nines
Idiom:Every cloud has a silver lining
Idiom:Eye for an eye
Idiom:Feet on the ground
Idiom:Fine words butter no parsnips
Idiom:Fire on all cylinders
Idiom:Fit as in fiddle
Idiom:Football is a game of two halves
Idiom:Have a trick up your sleeve
Idiom:In for a penny in for a pound
Idiom:Legend in your own lunchtime
Idiom:Needle in a haystack
Idiom:No time like the present
Idiom:Not enough room to swing a cat
Idiom:Oldest trick in the book
Idiom:Out of sight out of mind
Idiom:Quick on the trigger
Idiom:Rome was not built in a day