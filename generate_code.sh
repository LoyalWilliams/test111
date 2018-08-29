#!/bin/bash
source /etc/profile

path=`pwd`
mkdir -p $path/sql/replace
mkdir -p $path/sql/select
mkdir -p $path/awk
generate_awk(){
  table=$1
  echo table:$table
  keys='';values='';count=0;update=''
  for i in $(mysql -uroot -proot -hhadoop3 -e "desc result.$table"|awk 'NR != 1 {print $1","$2}')
  do
    line=($(echo $i|awk -F',' '{print $1,$2}'))
    count=$(expr $count + 1)
    key=${line[0]};is_num=${line[1]};
    flag=0
    if [[ $is_num == *decimal* ]] || [[ $is_num == *int* ]] || [[ $is_num == *double* ]] || [[ $is_num == *float* ]]
      then
          flag=1
    fi
    if [[ $flag == '1' ]]
      then
        values="$values\",\"\$$count"
    else
        values="$values\",\"\"trim('\"\$$count\"')\""
    fi
    keys="$keys,$key"
    update="$update,$key=\$$count"
   done

  keys=${keys#,};values=${values#*\",\"};update=${update#,}
#  echo keys:$keys
#  echo values:$values
  echo "#! /usr/bin/awk -f">$path/awk/$table.awk
  echo "{print \"replace into result.$table($keys) values(\"$values\");\"}">>$path/awk/$table.awk
  echo "select $keys from $table">$path/sql/select/select_$table.sql
}

#遍历result库，循环生成sql和awk脚本
for table in $(mysql -uroot -proot -hhadoop3 -e 'use result;show tables'|awk 'NR!=1{print $1}')
do
  generate_awk $table
cat >$path/main/$table"_main.sh"<<EOF
#!/bin/bash
source /etc/profile

dt="\$1"
if [[ "\$1" == "" ]]
  then
    dt=\$(date -d " 1 days ago "  "+%Y-%m-%d")
fi
hive -d dt=\$dt -f $path/sql/select/select_$table.sql |awk -F '\t' -f $path/awk/$table.awk > $path/sql/replace/replace_$table.sql
mysql -uroot -proot -hhadoop3 <$path/sql/replace/replace_$table.sql
EOF

done
