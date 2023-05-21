#!/bin/sh

dirPath="$(realpath "$1" )"
[ -z "${dirPath}" ] &&dirPath="$(realpath . )"
cd "${dirPath}"

# init
binDir="$(realpath "$(dirname $0)")"

find -xdev -type d 2>/dev/null |while read My ;do
  oldName="$(basename "$My")"
  dirName="$(dirname "$My")"

  # remove word from dir
  #echo "${oldName}" |tr '_, ' '-' >/tmp/newName$$
  echo "${oldName}" |tr '_, .' '-' >/tmp/newName$$
  echo "${dirName}" |sed -r "s#[^[:alnum:]]#\n#gI" |grep . |tr '[:upper:]' '[:lower:]' |sort -u |while read My2 ;do
    cat /tmp/newName$$ |sed -r "s#\b${My2}\b[^[:alnum:]]*##gI" >/tmp/newName$$2
    mv -f /tmp/newName$$2 /tmp/newName$$
  done

  #reverse
  cat /tmp/newName$$ |rev >/tmp/newName$$2
  mv -f /tmp/newName$$2 /tmp/newName$$
  # remove duplicates
  countMy=32
  while [ ! -z "$(cat /tmp/newName$$ |sed -r "s#[^[:alnum:]]#\n#gI" |grep . |tr '[:upper:]' '[:lower:]' |sort |uniq -c |awk '{if ($1>1) print $2}' |tee /tmp/duplicatesWords$$)" ] ;do
    cat /tmp/duplicatesWords$$ |while read My2 ;do
      cat /tmp/newName$$ |sed -r "s#[^[:alnum:]]*\b${My2}\b##I" >/tmp/newName$$2
      mv -f /tmp/newName$$2 /tmp/newName$$
    done
    countMy=$((countMy-1)) && [ $countMy -le 0 ] &&break
  done

  #newName=$(cat /tmp/newName$$ |rev |sed -r 's#\.+#\.#g' |sed -r 's#\-+#-#g' |sed -r 's#\.\-#-#g' |sed -r 's#\-\.#-#g' |sed -r 's#\-+$##' |sed -r 's#\.+$##' |sed -r 's#^\-+##' |sed -r 's#^\.+##')
  newName=$(cat /tmp/newName$$ |rev |sed -r 's#[-\.]+$##' |sed -r 's#^[-\.]+##' |sed -r 's#[-\.]{2,}#.#g')
  if [ "${oldName}" != "${newName}" ] ;then
    if [ -d "${dirName}/${newName}" ] ;then
      mv -vn "${dirName}/${oldName}"/* "${dirName}/${oldName}"/\.[^\.]* "${dirName}/${oldName}"/\.\.?* "${dirName}/${newName}"/.
      rmdir "${dirName}/${oldName}"
    else
      mv -vn "${dirName}/${oldName}" "${dirName}/${newName}"
    fi
#    "${binDir}"/mv.sh "${dirName}"/"${oldName}"/ "${dirName}"/"${newName}"/
  fi
done

