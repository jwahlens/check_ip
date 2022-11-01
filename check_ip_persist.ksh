#!/bin/ksh

# Set the polling rate, email list and world name.
sleep_time=600
emails="froodwithtowel@gmail.com,peskowron@gmail.com"
debug_emails="froodwithtowel@gmail.com"
#emails=$debug_emails
worldname="The Land of Cheese and Syrup"
ip_savefile=$PWD/last_good_ip.dat

# Set to "on" for debug
debug_messages="off"

if [ "$debug_messages" = "on" ]; then
  emails=$debug_emails
  sleep_time=5
fi

# Check what the current public IP is.
function get_ip {
  dig +short myip.opendns.com @resolver1.opendns.com
}

# Get the latest IP and retry if there is not network access untill it succeeds.
function get_new_ip {
  haveip=0
  while [[ $haveip -eq 0 ]]; do

    if [ "$debug_messages" = "on" ]; then
      print Checking the IP address
    fi

    ipchk=$(get_ip)

    #ipchk="foo"
    # For debugging, test the change path by giving each iteration a 1 in 4 chance of randomly changing
    if [ "$debug_messages" = "on" ]; then
      if [[ $RANDOM%4 -eq 1 ]]; then
        ipchk="$(($RANDOM%1000))"
      fi
    fi

    #Currently it checks that get_ip does not fail and the returned value is not blank.
    if [[ $? -ne 0 || -z $ipchk ]]; then
      print IP address aquisition failed. Trying again in $sleep_time seconds.
      sleep $sleep_time

    else

      if [ "$debug_messages" = "on" ]; then
        print Address is currently: $ipchk
      fi

      # Here is a check to make sure that the returned thing actually looks like an IP address.
      # Otherwise assume it is an error and try again in a bit.
      if expr "$ipchk" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        haveip=1
      else
        print IP value returned is: $ipchk
	print This fails validation, trying again in $sleep_time seconds.
	print This is probably a transient network error.
	sleep $sleep_time
      fi
    fi
  done
  new_ip=$ipchk
}

# This is the place where most time is spent. Here we simply poll until the address changes.
# If there is a change, update the IP and send an alert email.
function poll_for_ip_change {
  new_ip="1"
  ip_change=0
  while [[ $ip_change -ne 1 ]]; do

    if [ "$debug_messages" = "on" ]; then
      print Time to check for an IP change
    fi

    get_new_ip
    if [ "$new_ip" != "$current_ip" ]; then
      print IP address has changed from $current_ip to $new_ip.
      current_ip=$new_ip
      send_alert
      ip_change=1
      print $current_ip > $ip_savefile
    else

      if [ "$debug_messages" = "on" ]; then
        print Sleeping...
      fi

      sleep $sleep_time
    fi
  done
}

# Send an alert to the emails list
function send_alert {

if [ "$debug_messages" = "on" ]; then
print Sending out the following message to $emails :
print ''
print From: terrariaserverstatusgremlin@gmail.com
print Subject: $worldname has an update
print ''
print The new address is $current_ip
print ''
print - - $worldname
print ''
else
print sending an email out
fi

sendmail $emails <<EOF
From: terrariaserverstatusgremlin@gmail.com
Subject: $worldname has an update

The new address is $current_ip

- $worldname
EOF
}

function main {
  new_ip="1"
  if [[ -e "$ip_savefile" ]]; then
    current_ip=$(cat $ip_savefile)
  else
    get_new_ip
    current_ip=$new_ip
    print $current_ip > $ip_savefile
  fi
  while [ 1 ]; do
    poll_for_ip_change || break
    send_alert || break
  done
}

main

