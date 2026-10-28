on run
    try
        set resourceDir to POSIX path of (path to resource "discover.sh")
        set resourceDir to do shell script "/usr/bin/dirname " & quoted form of resourceDir
        set modeChoice to button returned of (display dialog "Instalar o driver comunitário Elgin i9 FULL2.\n\nBusque candidatos na rede local ou informe o IP. A busca verifica a porta 9100 sem imprimir; não identifica marca ou modelo.\n\nNão requer ferramentas de desenvolvimento." buttons {"Cancelar", "Informar IP", "Buscar na rede"} default button "Buscar na rede" cancel button "Cancelar" with title "Elgin i9 FULL2")
        set printerIP to ""
        if modeChoice is "Buscar na rede" then
            display dialog "A busca usa a interface da rota padrão e até 254 endereços do segmento IPv4 local, respeitando a máscara. Pode levar cerca de 30 segundos.\n\nSe o macOS pedir acesso à rede local, permita para encontrar a impressora." buttons {"Cancelar", "Buscar"} default button "Buscar" cancel button "Cancelar" with title "Buscar impressora"
            try
                with timeout of 180 seconds
                    set foundIPs to do shell script "/bin/sh " & quoted form of (resourceDir & "/discover.sh") & " --list"
                end timeout
            on error detail number code
                display dialog "Não foi possível concluir a busca. Você poderá digitar o IP.\n\n" & detail buttons {"Continuar"} default button "Continuar" with title "Busca indisponível"
                set foundIPs to ""
            end try
            if foundIPs is not "" then
                set candidates to paragraphs of foundIPs
                set end of candidates to "Informar outro IP"
                set selectedIP to choose from list candidates with title "Candidatos encontrados" with prompt "Confirme o IP da sua Elgin i9 FULL2. Outros modelos também podem aparecer." OK button name "Selecionar" cancel button name "Cancelar" without multiple selections allowed
                if selectedIP is false then return
                set printerIP to item 1 of selectedIP
                if printerIP is "Informar outro IP" then set printerIP to ""
            else
                display dialog "Nenhum candidato listado. Confira a conexão e informe o IP manualmente." buttons {"Continuar"} default button "Continuar"
            end if
        end if
        repeat
            if printerIP is "" then set printerIP to text returned of (display dialog "IP da Elgin i9 FULL2:" default answer "" buttons {"Cancelar", "Continuar"} default button "Continuar" cancel button "Cancelar")
            try
                do shell script "/bin/sh " & quoted form of (resourceDir & "/configure.sh") & " --validate " & quoted form of printerIP
                exit repeat
            on error
                display dialog "Informe um IPv4 válido, por exemplo 192.168.1.100." buttons {"Corrigir"} default button "Corrigir"
                set printerIP to ""
            end try
        end repeat
        display dialog "Instalar o driver e criar ou atualizar a fila ELGIN_I9 em " & printerIP & ":9100?\n\nA instalação substitui os arquivos do driver deste projeto e configura a conexão. Suas preferências de impressão podem continuar ativas. Nenhum cupom será impresso." buttons {"Cancelar", "Instalar"} default button "Instalar" cancel button "Cancelar" with title "Confirmar instalação"
        with timeout of 300 seconds
            do shell script "/usr/sbin/installer -pkg " & quoted form of (resourceDir & "/ElginI9Driver.pkg") & " -target / && /bin/sh " & quoted form of (resourceDir & "/configure.sh") & " " & quoted form of printerIP with administrator privileges
        end timeout
        display dialog "Driver instalado.\n\nSelecione Elgin i9 FULL2 e papel 72 mm × 297 mm. Feche e reabra seu aplicativo de impressão.\n\nNenhum teste foi impresso automaticamente." buttons {"Concluir"} default button "Concluir" with title "Instalação concluída"
    on error detail number code
        if code is not -128 then display dialog "A instalação não foi concluída.\n\n" & detail buttons {"Fechar"} default button "Fechar" with title "Elgin i9 FULL2"
    end try
end run
