#!/bin/bash
#UNTESTED, except for individual parts
#Script for verifying SSL certificate validity and remind expiry by mail
#Frequency should be bigger than the frequency at which the script is run at. This *should* make it so
#that the email is only sent once, since one execution only fits inside one frequency window.

enddate=`openssl s_client -servername $1:443 -connect $1:443 < /dev/null 2>/dev/null | openssl x509 -enddate | grep -i after | cut -d'=' -f 2`

statuscode=`openssl s_client -servername $1:443 -connect $1:443 < /dev/null 2>/dev/null | grep -i "Verify return code" | awk '{print $4}' `

enddatenumber=`date -d "$enddate" +%s`
curdatenumber=`date +%s`

monthlen=2592000
weeklen=604800
frequency=3600
mailuser="example@example.com" #Email here m8


if (( "$monthlen" + "$curdatenumber" > "$enddatenumber" )) ; then
    if (( "$monthlen" + "$curdatenumber" < "$enddatenumber" + "$frequency" )) ; then
        echo -e "Subject:SSL certificate expiry warning \n\n 1 Month warning, host: $1 \n" | sendmail -f sslchecker@ut.ee $mailuser
    fi
fi

if (( "$weeklen" + "$curdatenumber" > "$enddatenumber" )) ; then
    if (( "$weeklen" + "$curdatenumber" < "$enddatenumber" + "$frequency" )) ; then
        echo -e "Subject:SSL certificate expiry warning \n\n 1 Week warning, host: $1 \n" | sendmail -f sslchecker@ut.ee $mailuser
    fi
fi

if (( "$statuscode" != 0 )) ; then
    echo -e "Subject:SSL cert return code fail \n\n 1 Host: $1 \n" | sendmail -f sslchecker@ut.ee $mailuser
fi

