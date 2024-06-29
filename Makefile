all:
	vasmm68k_mot19f -DVAMPIRE -Fhunkexe -devpac -nocase -m68080 -DVAMPIRE  -o ./intervallo ./intervallo.s
	chmod 777 intervallo
install:
	scp ./intervallo pi@10.0.0.4:/media/MAXTOR/upload/Vampire/ProgrammazioneSAGA/