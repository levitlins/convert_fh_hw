#!/bin/bash

# - Efetuar backup da OLT via telnet com o comando show: 
#
# > startup-config 
#
# - Caso OLT esteja paginando executar o comando antes do enable: 
#
# > terminal length 0
#
# - Extrair as informacoes de: ObjectName,SlotNo,PONNo,ONUAuthorizedNo,PhysicalAddress direto do ANM2000
#   Clicando no modulo > selecionando todas as ONU > clicando com botao direito > export to csv
#   Repetir a operacao para todos os modulos e juntar todas as informacoes em um unico csv
# 
# - Os arquivos de backup da OLT e CSV do ANM devem estar na mesma pasta do script
#  
# - Configurar as variaveis abaixo com os nomes dos arquivos
#
# - Configurar offset do modulo de fiberhome para huawei
#
# Ex.  se o modulo na fiberhome for 1 e na huawei for 0 entao configurar offset=1
#      se o modulo na fiberhome for 2 e na huawei for 0 entao configurar offset=2
#      offset sera subtraido do modulo 
#      offset das portas PON nao e necessario o script ja efetua o offset
#
# - Configurar a porta de uplink na variavel abaixo onde sera configurada as vlans
#
# - Executar o script
#
# > bash convert_fh_hw.sh
#
# - Ao final da exceucao o script ira gerar 4 arquivos add_profile.txt, add_vlans.txt, add_onu_txt e add_service_hw.txt com as configuracoes a serem executadas
#
# - Antes de criar os profiles sera necessario criar o profile dba na OLT com ID: 10
#
# Ex.
# > dba-profile add profile-id 10 type4 max 512000

#  Arquivo de backup comando show startup-config executar primeiro o > terminal length 0 antes do > enable
arq_bkp="OLT.txt" 

# Juntar todos os modulos em um CSV exportado do ANM2000 no formato: ObjectName,SlotNo,PONNo,ONUAuthorizedNo,PhysicalAddress
arq_bkp_csv="OLT-ANM2000.csv"

# Offset do slot. valor que sera subtraido do slot da fiberhome Ex na fiberhome comecar do slot 1 offset deve ser 1 assim o slot huawei sera 0
offset_slot_hw="2"

# porta de uplink da olt huawei onde sera passada as vlans
hw_uplink="0/2 2"


output_add_onu="add_onu_hw.txt" # arquivo de output com os comandos para adicionar ONUs
output_add_service="add_service_hw.txt" # arquivo de output com os comandos para adicionar service port
output_add_profile="add_profile.txt" # arquivo de output com os comandos para adicionar os profiles P.S precisa criar o DBA com ID 10 primeiro 
output_add_vlan="add_vlans.txt" # arquivo de output com os comando para adicionar as vlans


if [ ! -e "$arq_bkp" ]; then { 
    echo " "
    echo " -- Verifique a configuracao da variavel arq_bkp"
    echo " "
    echo "            Arquivo $arq_bkp nao existe"
    echo " "
    exit 0
    }; fi

if [ ! -e "$arq_bkp_csv" ]; then {
    echo " "
    echo " -- Verifique a configuracao da variavel arq_bkp_csv"
    echo " "
    echo "            Arquivo $arq_bkp_csv nao existe"
    echo " "
    exit 0
    }; fi

# gera vlan onu service set
cat $arq_bkp | tr -d "\15" | grep "set ep" | grep "vlan" > arq_bkp_onu_id # filtra comandos vlan bridge

while read -r LINHA; do {

slot=`echo $LINHA | awk -F " " '{print $4}'`
pon_port=`echo $LINHA | awk -F " " '{print $6}'`
pon_port=`echo $pon_port | sed 's/ //g'`
onu_id=`echo $LINHA | awk -F " " '{print $8}'`
onu_id=`echo $onu_id | sed 's/ //g'`
onu_id_alt=$onu_id
vlan_id=`echo $LINHA | awk -F " " '{print $17}'`
vlan_id=`echo $vlan_id | sed 's/ //g'`


count_colum=`echo $onu_id | awk -F "," '{print NF }'`
  if [ $count_colum -ge 1 ]; then {
    for ((i=1; i<=$count_colum; i++)); do {
         colum=`echo $onu_id | awk -F "," '{print $'$i'}'`
         colum=`echo $colum | sed 's/ //g'`

         colum_num=`echo $colum | awk -F "-" '{print NF}'`
          if [ $colum_num -gt 1 ]; then {
            colum1=`echo $colum | awk -F "-" '{print $1}'`
            colum1=`echo $colum1 | sed 's/ //g'`
            colum2=`echo $colum | awk -F "-" '{print $2}'`
            colum2=`echo $colum2 | sed 's/ //g'`
            alt_colum=""
            for ((j=$colum1; j<=$colum2; j++)) do { 
                alt_colum=$alt_colum`echo $j`, 
                }; done

               alt_colum=`echo $alt_colum | sed 's/.$//g'` # retira virgula final loop
               alt_colum=`echo $alt_colum |  sed 's/ //g'` # retira qualquer espaco em branco

              onu_id_alt=`echo $onu_id_alt | sed "s/$colum/$alt_colum/g"`
 
#echo $slot $pon_port $onu_id_alt   #debug alteracoes          

          }; fi	
    }; done

#echo $slot $pon_port $onu_id_alt #debug alterado
#echo $slot $pon_port $vlan_id #debug

  }; fi


coluna_contar=`echo $onu_id_alt | awk -F "," '{print NF }'`
#echo $coluna_contar #debug qtd colunas

  if [ $coluna_contar -ge 1 ]; then {
     for ((k=1; k<=$coluna_contar; k++)); do {
       o_id=`echo $onu_id_alt | awk -F "," '{print $'$k'}'` 
       v_id=`echo $vlan_id | awk -F "," '{print $'$k'}'`
       onu_serial=`cat $arq_bkp | grep "ac add  sl $slot li $pon_port o $o_id ty" | awk -F " " '{print $5}'`
       onu_desc=`cat $arq_bkp_csv | sed 's/ //g' | grep "$onu_serial" | awk -F "," '{print $1}'`

  # Ajustar slot e pon port
  slot_hw=$[slot-offset_slot_hw]
  pon_port_hw=$[pon_port-1]
  nap_name=`cat $arq_bkp |tr -d "\15" |grep -m1 "vid_begin $v_id" |awk -F " " '{print $3}'`
    
  # output comandos add onu
  echo -e "interface gpon 0/${slot_hw}" >> $output_add_onu
  echo -e "ont add $pon_port_hw $o_id sn-auth $onu_serial omci ont-lineprofile-name $nap_name ont-srvprofile-id 1 desc $onu_desc" >> $output_add_onu 
  echo -e " " >> $output_add_onu
  echo -e "ont port native-vlan $pon_port_hw $o_id eth 1 vlan $v_id priority 0" >> $output_add_onu
  echo -e " " >> $output_add_onu
  echo -e "quit" >> $output_add_onu

  # output comandos add service
  echo -e "service-port vlan $v_id gpon 0/${slot_hw}/${pon_port_hw} ont $o_id gemport 1 multi-service user-vlan $v_id tag-transform translate" >> $output_add_service
  echo -e " " >> $output_add_service


#output_add_onu
#output_add_service

#echo Slot: $slot Pon: $pon_port ONU: $o_id Vlan: $v_id Tipo: serviceport
#echo Onu_id: $o_id Vlan_id: $v_id #debug
#echo -e "$slot $pon_port $o_id $v_id $onu_serial $onu_desc serviceport" #debug

     }; done     
  }; fi

}; done < arq_bkp_onu_id

rm arq_bkp_onu_id


cat $arq_bkp | grep "set ep" | grep "onuveip" | tr -d "\15" > arq_bkp_onu_id # filtra onuveio e retira caractere especial ^M do final de cada linha se n tiver ^M no arquivo retirar sed

while read -r LINHA; do {

slot=`echo $LINHA | awk -F " " '{print $4}'`
pon_port=`echo $LINHA | awk -F " " '{print $6}'`
pon_port=`echo $pon_port | sed 's/ //g'`
onu_id=`echo $LINHA | awk -F " " '{print $8}'`
onu_id=`echo $onu_id | sed 's/ //g'`
vlan_id=`echo $LINHA | awk -F " " '{print $14}'`
vlan_id=`echo $vlan_id | sed 's/ //g'`
onu_serial=`cat $arq_bkp | tr -d "\15" | grep "ac add  sl $slot li $pon_port o $onu_id ty" | awk -F " " '{print $5}'`
onu_desc=`cat $arq_bkp_csv | tr -d "\15" | sed 's/ //g' | grep "$onu_serial" | awk -F "," '{print $1}'`

 # Ajustar slot e pon port
  slot_hw=$[slot-offset_slot_hw]
  pon_port_hw=$[pon_port-1]
  nap_name=`cat $arq_bkp | tr -d "\15" | grep -m1 "vid_begin $vlan_id" |awk -F " " '{print $3}'`

  # output comandos add onu
  echo -e "interface gpon 0/${slot_hw}" >> $output_add_onu
  echo -e "ont add $pon_port_hw $onu_id sn-auth $onu_serial omci ont-lineprofile-name $nap_name ont-srvprofile-id 1 desc $onu_desc" >> $output_add_onu
  echo -e " " >> $output_add_onu
  echo -e "quit" >> $output_add_onu

  # output comandos add service
  echo -e "service-port vlan $vlan_id gpon 0/${slot_hw}/${pon_port_hw} ont $onu_id gemport 1 multi-service user-vlan $vlan_id tag-transform translate" >> $output_add_service
  echo -e " " >> $output_add_service


#echo "$slot $pon_port $onu_id $vlan_id $onu_serial $onu_desc Onuveip" # Debug

}; done < arq_bkp_onu_id

rm arq_bkp_onu_id


count_profile=1
touch "$output_add_profile"
cat $arq_bkp | tr -d "\15" | grep "set service" | grep "vid_begin" > arq_bkp_onu_id # filtra onuveio e retira caractere especiais

while read -r LINHA; do {

service_name=`echo $LINHA | awk -F " " '{print $3}'`
vid_begin=`echo $LINHA | awk -F " " '{print $5}'`

duplic=`cat "$output_add_profile" |grep "gem mapping 1 0 vlan $vid_begin priority 0" |wc -l |sed 's/ //g'`
#echo "$duplic"

  if [ "$duplic" -eq 0 ]; then {
    echo -e  "ont-lineprofile gpon profile-id $count_profile profile-name $service_name" >> $output_add_profile
    echo -e  "tcont 1 dba-profile-id 10" >> $output_add_profile
    echo -e  "gem add 1 eth tcont 1" >> $output_add_profile
    echo -e  " " >> $output_add_profile
    echo -e  "gem mapping 1 0 vlan $vid_begin priority 0" >> $output_add_profile
    echo -e  " " >> $output_add_profile
    echo -e  "commit" >> $output_add_profile
    echo -e  "quit" >> $output_add_profile
    
    count_profile=$[count_profile+1]
    
    echo -e "vlan $vid_begin smart" >> $output_add_vlan
    echo -e "port vlan $vid_begin $hw_uplink" >> $output_add_vlan

  }; fi

}; done < arq_bkp_onu_id

rm arq_bkp_onu_id




