#!/usr/bin/perl -w
#
# VIT - Visual Interactive Taskwarrior
#
# %BUILD%
#
# Copyright 2012 - 2013, Steve Rader
# Copyright 2013 - 2018, Scott Kostyshak

use strict;
use Curses;
use Time::HiRes qw(usleep);
use Try::Tiny;
use utf8;
use POSIX qw(setlocale LC_CTYPE WIFSIGNALED WIFEXITED WEXITSTATUS);
use I18N::Langinfo qw(langinfo CODESET);
use Encode;
use Text::CharWidth qw(mbswidth);

# Clean up terminal on a Perl error or warning. This makes it more clear what
# the error or warning message is and it leaves the terminal in a usable state.
$SIG{HUP} = sub { &error_exit("Received signal HUP"); };
$SIG{INT} = sub { &error_exit("Received signal INT"); };
$SIG{PIPE} = sub { &error_exit("Received signal PIPE"); };
$SIG{TERM} = sub { &error_exit("Received signal TERM"); };
$SIG{__DIE__} = sub { &error_exit(@_); };
# Exit even on Perl warning
$SIG{__WARN__} = sub { &error_exit("(converted from warning) "."@_"); };

our $commands_file = '%prefix%/share/vit/commands';
our $task = '%TASK%';
our $clear = '%CLEAR%';
if ( $commands_file =~ /^%/ ) { $commands_file = "./commands"; }
if ( $task =~ /^%/ ) { $task = '/usr/local/bin/task'; }
if ( $clear =~ /^%/ ) { $clear = '/usr/bin/clear'; }

our $cli_args = '';
our $audit = 0;
our @colors2pair;
our $convergence = '';
our $current_command = 'unknown';
our $cursor_position = 'unknown';
our $default_command = 'next';
our $default_tags = '';
our $default_tags_add = '';
our $display_start_idx = 0;
our $error_delay = 500000;
our $error_msg = '';
our $flash_convergence = 0;
our $flash_delay = 80000;
our $header_win;
our $header_attrs;
our $input_mode = 'cmd';
our $num_projects = 0;
our $num_tasks = 0;
our $feedback_msg = '';
our @parsed_tokens = ();
our @parsed_colors_fg = ();
our @parsed_colors_bg = ();
our @parsed_attrs = ();
our $prev_display_start_idx;
our $prev_ch = '';
our $prev_command = 'next';
our $prev_convergence = '';
our $prev_task_selected_idx;
our @project_types = ();
our @tag_types = ();
our $prompt_win;
our $refresh_needed = 0;
our $reread_needed = 0;
our $report_descr = 'unknown';
our $report_win;
our @report_header_tokens = ();
our @report_header_colors_fg = ();
our @report_header_colors_bg = ();
our @report_header_attrs = ();
our @report_tokens = ();
our @report_lines = ();
our @report_types = ();
our @report_colors_fg = ();
our @report_colors_bg = ();
our @report_attrs = ();
our @report2taskid = ();
our $search_direction = 1;
our $search_pat = undef;
our $selection_attrs = '';
our @taskid2report = ();
our $tasks_completed = 0;
our $tasks_pending = 0;
our $task_selected_idx = 0;
our $titlebar = 0;
our $version = '%VERSION%';
our $REPORT_LINES;
our $REPORT_COLS;

our $COLOR_HEADER = 1;
our $COLOR_REPORT_HEADER = 2;
our $COLOR_SELECTION = 3;
our $COLOR_EMPTY_LINE = 4;
our $COLOR_ERRORS = 5;
our $next_color_pair = 6;

our %shortcuts;
our $cur_pos;
our %histories;

# are we in a "try" block? If so, quick return from END block
our $during_try = 0;

# vitrc settings
my $burndown = "no";
my $show_empty_report = "no";
my $confirmation = 1;
my $nowait = undef;

require 'args.pl';
require 'cmdline.pl';
require 'cmds.pl';
require 'color.pl';
require 'exec.pl';
require 'curses.pl';
require 'draw.pl';
require 'env.pl';
require 'getch.pl';
require 'misc.pl';
require 'prompt.pl';
require 'read.pl';
require 'screen.pl';
require 'search.pl';

###################################################################
## main...

&parse_args();
&parse_vitrc();
&init_shell_env();
&init_curses('init');
&init_task_env();
&read_report('init');
&draw_screen();
&getch_loop();
&clean_exit();
