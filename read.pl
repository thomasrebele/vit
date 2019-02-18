# Copyright 2012 - 2013, Steve Rader
# Copyright 2013 - 2018, Scott Kostyshak

sub read_report {
  my ($mode) = @_;
  &inner_read_report($mode);
  if ( $error_msg =~ /Error: task .*: no matches/ ) {
    # take care of marking last done...
    &inner_read_report('init');
  }
  if ( $current_command eq 'summary' ) {
    &get_num_tasks();
  }
}

#------------------------------------------------------------------

sub inner_read_report {
  my ($mode) = @_;

  my $report_header_idx = 0;
  my $args;
  my @prev_num_tasks = $num_tasks;
  my @prev_report2taskid = @report2taskid;
  my @prev_report_tokens = @report_tokens;
  my @prev_report_lines = @report_lines;
  my @prev_report_colors_fg = @report_colors_fg;
  my @prev_report_colors_bg = @report_colors_bg;
  my @prev_report_attrs = @report_attrs;
  my @prev_report_header_tokens = @report_header_tokens;
  my @prev_report_header_attrs = @report_header_attrs;
  $prev_convergence = $convergence;

  $prev_display_start_idx = $display_start_idx;
  $prev_task_selected_idx = $task_selected_idx;
  @report2taskid = ();
  @report_tokens = ();
  @report_lines = ();
  @report_colors_fg = ();
  @report_colors_bg = ();
  @report_attrs = ();
  @report_header_tokens = ();
  @report_header_attrs = ();
  @project_types = ();
  if ( $mode eq 'init' ) {
    $task_selected_idx = 0;
    $display_start_idx = 0;
  }

  &audit("EXEC $task stat 2>&1");
  open(IN,"$task stat 2>&1 |");
  while(<IN>) {
    chop;
    if ( $_ =~ /^\s*$/ ) { next; }
    $_ =~ s/\x1b.*?m//g;
    if ( $_ =~ /Pending\s+(\d+)/ ) {
      $tasks_pending = $1;
      next;
    }
    if ( $_ =~ /Completed\s+(\d+)/ ) {
      $tasks_completed = $1;
      next;
    }
  }
  close(IN);

  if ( $burndown eq "yes" ) {
    $args = "rc.defaultwidth=$REPORT_COLS rc.defaultheight=$REPORT_LINES burndown";
    &audit("EXEC $task $args 2>&1");
    open(IN,"$task $args 2>&1 |");
    while(<IN>) {
      if ( $_ =~ /Estimated completion: No convergence/ ) {
        $convergence = "no convergence";
        last;
      }
      if ( $_ =~ /Estimated completion: .* \((.*)\)/ ) {
        $convergence = "convergence in $1";
        last;
      }
    }
    close(IN);
    if ( $convergence ne $prev_convergence && $prev_convergence ne '' ) {
      $flash_convergence = 1;
    } else {
      $flash_convergence = 0;
    }
  }

  &audit("EXEC $task projects 2>&1");
  open(IN,"$task projects 2>&1 |");
  while(<IN>) {
    chop;
    if ( $_ =~ /^\s*$/ ) { next; }
    $_ =~ s/\x1b.*?m//g;
    if ( $_ =~ /^\w+ override/ ) { next; }
    if ( $_ =~ /^Project/ ) { next; }
    if ( $_ =~ /^\d+ project/ ) { next; }
    my $p = (split(/\s+/,$_))[0];
    if ( $p eq '(none)' ) { next; }
    push(@project_types, $p);
  }
  close(IN);

  {
    &audit("EXEC $task tags 2>&1");
    @tag_types=();
    open(IN,"$task tags 2>&1 |");
    my $_started = undef;
    while (my $line=<IN>) {
      # list of tasks starts after a line containing "--- -----"
      if ($line =~ /^-+ -+$/) {
        $_started = 1;
        next;
      }
      next unless $_started;

      # save tag in first field of line
      chomp $line;
      last if $line eq '';
      my $t = ( split(/\s+/,$line) )[0];
      push(@tag_types, $t);
    }
    close(IN);
  }

  $args = "rc.defaultwidth=$REPORT_COLS rc.defaultheight=0 rc._forcecolor=on $current_command";
  &audit("EXEC $task $args 2> /dev/null");
  open(IN,"$task $args 2> /dev/null |");
  my $i = 0;
  my $prev_id;
  while(<IN>) {
    chop;
    $_ = &decode_utf8($_);
    if ( $_ =~ /^\s*$/ ) { next; }
    if ( $_ =~ /^(\d+) tasks?$/ ||
         $_ =~ /^\x1b.*?m(\d+) tasks?\x1b\[0m$/ ||
         $_ =~ /^\d+ tasks?, (\d+) shown$/ ||
         $_ =~ /^\x1b.*?m\d+ tasks?, (\d+) shown\x1b\[0m$/ ) {
      $num_tasks = $1;
      next;
    }
    &parse_report_line($i,$_);
    $_ =~ s/\x1b.*?m//g;
    $report_lines[$i] =  $_;

    # check if this is the header line
    if ( $_ =~ /^ID / ) {
      $report_header_idx = $i;
      $i++;
      next;
    }

    if ( $_ =~ /^\s{0,5}(\d+) / ) {
      $report2taskid[$i] = $1;
      $taskid2report[$1] = $i;
      &audit("inner_read_report: report2taskid[$i]=$1, taskid2report[$1]=$i")
    } else {
      $report2taskid[$i] = $prev_id;
      audit("inner_read_report: report2taskid[$i]=$prev_id")
    }
    $prev_id = $report2taskid[$i];
    $i++;
  }
  close(IN);

  if ( $#report_tokens > -1 ) {
    # TODO: this code is quite hard to understand; should probably be rewritten
    #       or at least needs explanation of what is happening here. [BaZo]
    @report_header_tokens = @{ $report_tokens[$report_header_idx] };
    @report_header_attrs = @{ $report_attrs[$report_header_idx] };
    splice(@report_tokens,$report_header_idx,1);
    splice(@report_lines,$report_header_idx,1);
    splice(@report_colors_fg,$report_header_idx,1);
    splice(@report_colors_bg,$report_header_idx,1);
    splice(@report_attrs,$report_header_idx,1);
    splice(@report2taskid,$report_header_idx,1);
    for (0..$#taskid2report) {
      $taskid2report[$_]-- if ($_>=$report_header_idx)
    }
    if ( $task_selected_idx > $#report_tokens ) {
      $task_selected_idx = $#report_tokens;
    }
  } else {
    $error_msg = "Error: task $current_command: no matches";

    if ( $show_empty_report eq "yes" ) {
      @report_header_tokens = ("NO MATCHES");
    }
    else {
      $current_command = $prev_command;
      $display_start_idx = $prev_display_start_idx;
      $task_selected_idx = $prev_task_selected_idx;
      @report_header_tokens = @prev_report_header_tokens;
      @report_header_attrs = @prev_report_header_attrs;
      @report_tokens = @prev_report_tokens;
      @report_lines = @prev_report_lines;
      @report_colors_fg = @prev_report_colors_fg;
      @report_colors_bg = @prev_report_colors_bg;
      @report_attrs = @prev_report_attrs;
      @report2taskid = @prev_report2taskid;
      $convergence = $prev_convergence;
    }

    return;
  }

}

#------------------------------------------------------------------

sub get_num_tasks {
  $num_tasks = 0;
  &audit("EXEC $task projects 2> /dev/null");
  open(IN,"$task projects 2> /dev/null |");
  while(<IN>) {
    if ( $_ =~ /(\d+) task/ ) {
      $num_tasks = $1;
      last;
    }
  }
  close(IN);
}

#------------------------------------------------------------------

return 1;

