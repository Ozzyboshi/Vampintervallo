all:
	vasmm68k_mot19f -DVAMPIRE -Fhunkexe -devpac -nocase -m68080 -DVAMPIRE  -o ./vampintervallo ./intervallo.s
	vasmm68k_mot19f -DVAMPIRE -Fhunkexe -devpac -nocase -m68080 -DVAMPIRE -DCOLORDEBUG  -o ./intervallocolordebug ./intervallo.s

	chmod 777 intervallo
install:
	scp ./vampintervallo pi@10.0.0.4:/media/MAXTOR/upload/Vampire/ProgrammazioneSAGA/
	scp ./intervallocolordebug pi@10.0.0.4:/media/MAXTOR/upload/Vampire/ProgrammazioneSAGA/