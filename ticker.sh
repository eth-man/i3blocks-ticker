#!/usr/bin/env bash
set -e

LANG=C
LC_NUMERIC=C

SYMBOLS=$1
purchprice=$2
stocks=$3
warning=$4


FILE="$HOME/.local/bin/statusbar/ticker.enabled"
if [ -f "$FILE" ]; then

if ! $(type jq > /dev/null 2>&1); then
  echo "'jq' is not in the PATH. (See: https://stedolan.github.io/jq/)"
  exit 1
fi

if [ -z "$SYMBOLS" ]; then
	echo "Usage: ./ticker.sh AAPL (buy price) (amount of stocks) (notify high) (notify low) <warn>"
  exit
fi






FIELDS=(symbol marketState regularMarketPrice regularMarketChange regularMarketChangePercent \
  preMarketPrice preMarketChange preMarketChangePercent postMarketPrice postMarketChange postMarketChangePercent)
API_ENDPOINT="https://query1.finance.yahoo.com/v7/finance/quote?lang=en-US&region=US&corsDomain=finance.yahoo.com"


BOLD='<span font-weight="bold">'
GREEN='<span color="#32CD32">'
RED='<span color="#DC143C">'
span="</span>"
#expected format
#<span color="#1793D1"></span>
if [ -z "$NO_COLOR" ]; then
 : "${COLOR_BOLD:=<span foreground=\"$1_color\">}"
 : "${COLOR_GREEN:=\e[32m}"
 : "${COLOR_RED:=\e[31m}"
 : "${COLOR_RESET:=\e[00m}"
fi

symbols=$(IFS=,; echo "${SYMBOLS[*]}")
fields=$(IFS=,; echo "${FIELDS[*]}")

results=$(curl --silent "$API_ENDPOINT&fields=$fields&symbols=$symbols" \
  | jq '.quoteResponse .result')

## i created this to see the api query
#results_test="$API_ENDPOINT&fields=$fields&symbols=$symbols"
#echo $results_test

query () {
  echo $results | jq -r ".[] | select(.symbol == \"$1\") | .$2"
}

for symbol in $(IFS=' '; echo "${SYMBOLS[*]}" | tr '[:lower:]' '[:upper:]'); do
  marketState="$(query $symbol 'marketState')"

  if [ -z $marketState ]; then
    printf 'No results for symbol "%s"' $symbol
    continue
  fi

  preMarketChange="$(query $symbol 'preMarketChange')"
  postMarketChange="$(query $symbol 'postMarketChange')"

  if [ $marketState == "PRE" ] \
    && [ $preMarketChange != "0" ] \
    && [ $preMarketChange != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'preMarketPrice')
    diff=$preMarketChange
    percent=$(query $symbol 'preMarketChangePercent')
  elif [ $marketState = "CLOSED" ] \
    && [ $postMarketChange != "0" ] \
    && [ $postMarketChange != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'regularMarketPrice')
    diff=$(query $symbol 'regularMarketChange')
    percent=$(query $symbol 'regularMarketChangePercent')
    preclose=$(query $symbol 'regularMarketPreviousClose')
  elif [ $marketState != "REGULAR" ] \
    && [ $postMarketChange != "0" ] \
    && [ $postMarketChange != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'postMarketPrice')
    diff=$postMarketChange
    percent=$(query $symbol 'postMarketChangePercent')
  else
    nonRegularMarketSign=''
    price=$(query $symbol 'regularMarketPrice')
    diff=$(query $symbol 'regularMarketChange')
    percent=$(query $symbol 'regularMarketChangePercent')
  fi

  if [ "$purchprice" != "" ]; then
	 percentP=$(awk "BEGIN {printf \"%.2f%%\",100*(${price}/${purchprice}-1)}")
	 #echo $percentP
  fi

#color for regular price
  if [ "$diff" == "0" ]; then
    color=
  elif ( echo "$diff" | grep -q ^- ); then
    color=$RED
  else
    color=$GREEN
  fi

#color for total purchase price
  if [ "$percentP" == "0" ]; then
    color2=
  elif ( echo "$percentP" | grep -q ^- ); then
    color2=$RED
  else
    color2=$GREEN
  fi


  if [ "$price" != "null" ]; then
    printf "$BOLD%-1s$span %1.2f%1s" $symbol $price
    printf "$color%5.2f%1s$span" $diff $(printf "(%.2f%%)" $percent)
    printf "$color2%s$span" $percentP
    printf "%s" "$nonRegularMarketSign"
  fi
echo " "



# Notify if you loosing money, 5000 means 5 second make sure you using same time in i3blocks conf
  if [ "$warning" = "warn" ]; then
	if ( echo "$percentP" | grep -q ^- ); then
	pgrep -x dunst >/dev/null && notify-send -t 5000 "🤑 Stocks Puller Notify" "\- $( printf "Warning - %s buy change has reachd to %s" $symbol $percentP)"
fi
  fi

case $BLOCK_BUTTON in
    #1) ;;
    2) $BROWSER "https://finance.yahoo.com/quote/$symbol";;
    3) pgrep -x dunst >/dev/null && notify-send -t 15000 "🤑 Stocks Puller" "\- $( printf "%-1s current Price %1.2f USD" $symbol $price)
- $(printf "Pre Close    %s$" $preclose)
- $(printf "Daily Change %5.3f$"  $diff )
- $(printf "Daily Change %.4f%%" $percent)
- $(printf "Buy Change   %s" $percentP)
- $(printf "Buy Profit   %s" $(awk "BEGIN {printf \"%.2f$\", $stocks*(${price}-${purchprice})}") )
- Market status $marketState"  ;;
esac


done


else
#	file not exist script will not run
	echo ""
fi
