#!/bin/bash
java -jar tools/PlayGame.jar maps/map$1.txt 1000 1000 log.txt "ruby MyBot.rb" "java -jar example_bots/DualBot.jar" | java -jar tools/ShowGame.jar &
