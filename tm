#!/bin/sh
# qdbus org.kde.konsole $KONSOLE_DBUS_SESSION setTitle 1 $(uname -n)
#printf "\033]0;%s@%s\007" "${USER}" "$(hostname)"
#cols=$(tput cols)
echo -e "\e]0;$(hostname -s)-${1}\a"
do_tmux_default() {
	tmux attach-session -t john$1 || \
	tmux new-session -s john$1 \; \
	split-window -h \; \
	split-window -v -d \; \
	resize-pane -U 100 \; \
	resize-pane -D 6 \; \
	select-pane -t 1 \; \
	split-window -h -l 60 \; \
	split-window -h -l 35 \; \
	clock-mode \; \
	select-pane -t 2 \; \
	send-keys 'cal  && read' 'C-m' \; \
	select-pane -t 4 \; \
	select-pane -t 0\;
}

do_tmux_standard() {
	tmux attach-session -d -t john$1 || \
	tmux new-session -s john$1 \;\
	split-window -h -p 66 \; \
	split-window -h -p 50 \; \
	split-window -v -d -p 50 \; \
	resize-pane -U 100 \; \
	resize-pane -D 6 \; \
	select-pane -t 2 \; \
	split-window -h -l 60 \; \
	split-window -h -l 35 \; \
	clock-mode \; \
	select-pane -t 3 \; \
	send-keys 'cal  && read' 'C-m' \; \
	select-pane -t 4 \; \
	select-pane -t 1\;
}

do_tmux_tripane() {
	tmux attach-session -d -t john$1 || \
	tmux new-session -s john$1 \; \
	split-window -v -d \; \
	split-window -v -d \; \
	select-layout even-horizontal \; \
	split-window -v -t 0 \; \
	split-window -v -t 3 \; \
	select-pane -t 3 \;
}

do_tmux_lores() {
	tmux attach-session -d -t john$1 || \
	tmux new-session -s john$1 \; \
	split-window -d \; \
	split-window -d \; \
	select-layout tiled \; \
	select-pane -t 2 \;
}

case $(cat /etc/hostname) in
	'syke-01A')
	do_tmux_tripane $*
	;;
	'john-dev')
	do_tmux_tripane $*
	;;
	'dz68')
	do_tmux_standard $*
	;;
	*)
	do_tmux_lores $*
	;;
esac
