#Lista todas as tabelas e views do DBC
Function SQL1 {
    $sql = "
    SEL DISTINCT databasename
    FROM DBC.Tables
    WHERE DatabaseName <> CreatorName
    ORDER BY 1;"
    return $sql
}

#Traz a data de alteração registrada do arquivo especificado
Function SQL2 { param([string]$arquivo)
    $sql =
    "SEL DISTINCT CAMINHO || '\' || ARQUIVO AS ARQ, DT_ULT_ALTERACAO
    FROM CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS
    WHERE ARQ = '$arquivo';"
    return $sql
}

#Traz a data de alteração registrada de todos arquivos
Function SQL2_v2 {
    $sql =
    "LOCK TABLE CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS FOR ACCESS
    SEL DISTINCT CAMINHO || '\' || ARQUIVO AS ARQ, DT_ULT_ALTERACAO
    FROM CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS;"
    return $sql
}

#Deleta arquivo especificado
Function SQL3 { param([string]$arquivo)
    $sql = "DEL FROM CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS WHERE CAMINHO || '\' ||ARQUIVO = '$arquivo';"
    return $sql
}

#Coleta estatísticas nas colunas CAMINHO e ARQUIVO
Function SQL4 {
    $sql =
    "COLLECT STATISTICS COLUMN (CAMINHO, ARQUIVO) ON CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS;"
    return $sql
}

#Lista todos os arquivos registrados
Function SQL5 {
    $sql =
    "SEL DISTINCT CAMINHO || '\' ||ARQUIVO AS ARQUIVO
    FROM CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS
    WHERE IND_ATIVO = 1;"
    return $sql
}

#Marca como inativo o arquivo especificado
Function SQL6 { param([string]$arquivo)
    $sql =
    "UPDATE CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS SET IND_ATIVO = 0 WHERE CAMINHO || '\' ||ARQUIVO = '$arquivo';"
    return $sql
}

#Função para executar SQL
Function Roda-SQL { param([string]$SQL)
    $cmd   = New-Object System.Data.Odbc.OdbcCommand($SQL, $conn)
    $cmd.CommandTimeout = 900000
    $da    = New-Object System.Data.Odbc.OdbcDataAdapter($cmd)
    $dados = New-Object System.Data.Datatable
    $null = $da.fill($dados)
    $cmd.Dispose()
    $da.Dispose()
    return $dados
}

#Funcão genérica de envio de e-mail
Function Envia-Email { param([string]$emails, [string]$assunto, [string]$texto)
    $assinatura = 
        "<br/>
        <br/>Att
        <br/>"
    $Outlook = New-Object -ComObject Outlook.Application
    $Mail = $Outlook.CreateItem(0)
    $Mail.To = $emails
    $Mail.Subject = $assunto
    $mail.HTMLBody = "<font face = Calibri>" + $texto + $assinatura
    $Mail.Send()
}

#Lista operadores do Teradata
Function Lista-Operadores-Teradata {
    $listaOperadores = @(
        "SELECT","SEL","MLOAD","CREATE","REPLACE","CT","DROP","DELETE","DEL","INS","INSERT","MERGE","UPDATE","COLLECT"
        ,"LOCKING","LOCK","INNER","LEFT","RIGHT","FULL","OUTER","CROSS","JOIN"
    )    
    return $listaOperadores
}

#Lista Operadores Join do Teradata
Function Lista-Operadores-Join-Teradata {
    $listaOperadores = @("INNER","LEFT","RIGHT","FULL","OUTER","CROSS")  
    return $listaOperadores
}

##########mudar dispois
#Limpa texto especificado
Function Limpa-String { param([string]$tabela)
    $tabela = $tabela.Trim()
    if($tabela.IndexOf("	") -gt 0) {
        $tabela = $tabela.Split("	")[0].trim()
    }
    $tabela = $tabela.Replace(")","")
    $tabela = $tabela.Replace("(","")
    $tabela = $tabela.Replace(";","")
    $tabela = $tabela.Replace(" AS","")
    $tabela = $tabela.Replace(",","")
    $tabela = $tabela.Replace("*/","")
   
    $tabela = $tabela.Replace("'","")
    $tabela = $tabela.Replace("""","")
    $tabela = $tabela.Replace("-","")
    $tabela = $tabela.Trim()    
    return $tabela
}

#Execução
try {

    $hoje = (Get-Date).ToString("dd/MM/yyyy")
    $dataInicio = "'" + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + "'"
    #$ErrorActionPreference = "Stop"
    Write-Host (Get-Date).ToString("HH:mm:ss") "Definindo parâmetros iniciais"
    
    $dirMapear = "C:\Users\usuario\Downloads"#diretorio para mapear
    
    $dirProcesso = "$dirMapear##Automatizacoes\10_Mapeamento_Tabelas\"
    $listaOperadores = Lista-Operadores-Teradata
    $listaOperadoresJoin = Lista-Operadores-Join-Teradata
    $arquivolog = ""
    $erro = 0
    $qtdColunas = "-1"
    $conteudoArquivo = ""
    $teste = ""
    $teste2 = ""

    Write-Host (Get-Date).ToString("HH:mm:ss") "Conectando ao Teradata"
    $conn = New-Object System.Data.Odbc.OdbcConnection("DSN=Teradata")
    $conn.open()
    
    Write-Host (Get-Date).ToString("HH:mm:ss") "Recuperando arquivos"
    $arquivosTotal = Get-ChildItem $dirMapear -Recurse -File | Where-Object {
        $_.LastWriteTime -ge ([datetime]::today).AddDays(-14) -and
        $_.Extension -in ".sql", ".ps1", ".psm1", ".btq" -and 
        $_.FullName.ToUpper() -notmatch "OLD" -and
        $_.FullName.ToUpper() -notmatch "BKP" -and
        $_.FullName.ToUpper() -notmatch "HIST" -and
        $_.FullName.ToUpper() -notmatch "BACKUP"
    } | echo

    Write-Host (Get-Date).ToString("HH:mm:ss") "Listando bases"
    $listaDatabases = Roda-SQL -SQL (SQL1)
 
    Write-Host (Get-Date).ToString("HH:mm:ss") "Filtrando arquivos editados nos últimos 4 dias"
    $arquivos = @()
    forEach($arquivo in $arquivosTotal) {
        if ($arquivo.LastWriteTime -ge ([datetime]::today).AddDays(-4)) {
            $arquivos += $arquivo
        }
    }    
  
    #CODIGO NOVO ADICIONADO
    $todosArquivos = Roda-SQL -SQL (SQL2_v2)


    $contador = 0
    forEach($arquivo in $arquivos) {
        $contador++
        Write-Host $contador "/" $arquivos.count

        Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Verificando"

        if( !$arquivo -or ($contador -gt 5335 -and $contador -lt 7191) -or ( $arquivo.FullName -like "*Modelagem_PublicoNPS*" ) ){
            continue
        }

        $insereArquivo = ""
        $arquivolog = $arquivo.FullName
        
        #CODIGO NOVO ADICIONADO PARA SUBSTITUIR A CONSULTA ACIMA
        $tabelas = $todosArquivos | Where-Object { $_.arq -in $arquivo.FullName }

        if($tabelas) {
            #Ignora arquivos que não tiveram alteração
            if ($tabelas[1] -eq $arquivo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) {
                Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Ignorando"
                continue
            }
            #Remove da tabela arquivos que tiveram alteração
            else {
                Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Limpando" -ForegroundColor Yellow
                #$sql = SQL3 -arquivo $arquivo.FullName
                Roda-SQL -SQL (SQL3 -arquivo $arquivo.FullName)
            }
        }

        #Mapeia arquivos novos ou editados
        Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Mapeando"
        $conteudoArquivo = (Get-Content $arquivo.FullName)   

        $ordem = 0  #ocorrencia de tabelas no mesmo script
        #$linha=160
        for( $linha=0; $linha -lt $conteudoArquivo.Count; $linha++ ){

            $dataBaseEncontrada = $false
            foreach($database in $listaDatabases){
                $nome = [string]$database.DatabaseName.Trim()
                $nome += ".*"
                if( [string]$conteudoArquivo[$linha].ToUpper().Trim() -match $nome ){
                    $dataBaseEncontrada = $true
                    break;
                }
            }  ## fim laço pesquisa de databases 
            if( $dataBaseEncontrada ) {
                $vetor = ($conteudoArquivo[$linha].Trim()).Split(' ') #.Split('`t')
                $vetor = $vetor.Split('	')
        
                #pesquisa o nome da tabela e atribui para a variável: $listaTabela
                foreach ($tabela in $vetor) {

                    $nomeBaseEncontrada = $false
                    foreach($database in $listaDatabases){
                        $nome = [string]$database.DatabaseName.Trim()
                        $nome += ".*"
                        if( $tabela -like $nome ){
                            $nomeBaseEncontrada = $true
                            break;
                        }
                    }

                    if( $nomeBaseEncontrada ){
                        $tabela = Limpa-String -tabela $tabela
    #                   Write-Host $linha+1 "encontrou: " $tabela

                        ###
                        ## VERIFICA SE ESTÁ COMENTADO
                        ##
                        $comentada = $false
                        $finalComentario = $false
                        # pesquisa na mesma linha se tem traço-traço
                        if( $conteudoArquivo[$linha] -match $tabela ){
                            # pega posicao inicial do nome da tabela
                            $coluna = $conteudoArquivo[$linha].IndexOf($tabela)
                            for( $col = $coluna; $col -ge 0; $col-- ){
                                $comentada = $false
                                # pesquisa comentário de uma linha apenas
                                if( $conteudoArquivo[$linha][$col] -eq "-" -and $conteudoArquivo[$linha][$col-1] -eq "-" ){
                            #        Write-Host "Achou comentario. " $linha[$col-1] " e " $linha[$col]
                                    $comentada = $true
                                    break
                                }
                            }
                        }

                        # usar variável $conteudo ao invés de $linha
                        if( !$comentada ){
                            $numLinhaDoArquivo = $linha
                            for($linhaAtualParaPesquisar = $numLinhaDoArquivo; $linhaAtualParaPesquisar -ge 0; $linhaAtualParaPesquisar-- ){
                                $cancelar=$false
                                $ultimaColuna = $conteudoArquivo[$linhaAtualParaPesquisar].Length - 1 #-1 por causa do \n
                                # alterar para
                                #
                                # $ultimaColuna = $conteudo[$linhaAtualParaPesquisar].IndexOf($tabela)
                                #
                                #
                                # pesquisa se esta dentro de comentário                                         
                                for( $col = $ultimaColuna; $col -ge 0; $col-- ){
                                    # verifica se existe final de bloco de comentário, exemplo: */
                                    if( $conteudoArquivo[$linhaAtualParaPesquisar][$col] -eq "/" -and $conteudoArquivo[$linhaAtualParaPesquisar][$col-1] -eq "*" ){
                                    #      Write-Host "Achou final comentario primeiro. Significa que a tabela nao está dentro de um bloco comentado." $col
                                        $finalComentario = $true
                                        break
                                    }
                                    if( $conteudoArquivo[$linhaAtualParaPesquisar][$col] -eq "*" -and $conteudoArquivo[$linhaAtualParaPesquisar][$col-1] -eq "/" ){
                                    #      Write-Host "Achou comentario. " $conteudo[$linhaAtualParaPesquisar][$col-1] " e " $conteudo[$linhaAtualParaPesquisar][$col]
                                    #      Write-Host $col
                                        $comentada = $true
                                        break
                                    }
                                }

                                # se for TRUE entao a base está comentada
                                # se for FALSE entao a base nao está comentada. DESCARTAR. Não inserir na lista
                                # if para sair do laço
                                if( $comentada ){
                                    #base ESTÁ em bloco comentado
                                    break;
                                }
                                #
                                # se achou final de comentario primeiro. Entao, nao esta comentada a tabela
                                #
                                if( $finalComentario ){
                                    #base NÃO ESTÁ em bloco comentado
                                    break;
                                }
                            }
                        }
                        ###
                        ##
                        ###
                        if ( $comentada ){
                            #Write-Host 'esta comentado'
                        }else{
                           #Write-Host 'nao esta comentado'
                                       
                            #$indiceDaTabelaNaLinha = $vetor.Count  #quantidade de 'colunas' na linha                                           
                            $copiaLinhaIndice = $linha
                            for( $indice=$copiaLinhaIndice; $indice -gt -1 ; $indice--){
                        
                                ###
                                ## VERIFICA O COMANDO UTILIZADO
                                ###
                   
                                #
                                # pesquisa na linha inteira novamente
                                #
                                $achouOp=$false
                                forEach($op in $listaOperadores){
                                    if( $conteudoArquivo[$indice] -match $op ){
                                       #Write-Host "achou op na linha" $conteudoArquivo[$indice]
                                        #$operador = $vetor
                                        $achouOp=$true
                                        break
                                    }
                                }
                            
                                if( $achouOp ){                           

                                   #Write-Host "indice: " $indice
                                    #Write-Host "operador: " $operador
                                    #
                                    # pesquisa o operador que foi encontrado na linha, a partir do indice da variavel $tabela
                                    #
                                    $elemDaLinha = $conteudoArquivo[$indice].Split(" ").Split("`t")                                

                                    $indiceNomeDaTabelaNaLinha = ""
                                    for($col=0; $col -lt $elemDaLinha.Count; $col++){
                                        if( $elemDaLinha[$col] -match $tabela ){
                                            $indiceNomeDaTabelaNaLinha = $col
                                            break
                                        }
                                    }
                                    if( $indiceNomeDaTabelaNaLinha -like $null ){
                                        $indiceNomeDaTabelaNaLinha = $elemDaLinha.Count-1
                                    }
                                
                                    if( $elemDaLinha.GetType().BaseType -match "Array" ){
                                        #eh vetor

                                        for($col=$indiceNomeDaTabelaNaLinha; $col -ge 0; $col--){
                                            $ele=""
                                            if( $elemDaLinha[$col].LENGTH -ne 1 ){
                                                $ele = Limpa-String -tabela $elemDaLinha[$col].replace("CAST('", "").Replace("'","")
                                            }
                                    
                                            if( $ele -like "" ){ continue }    
                                            forEach($op in $listaOperadores){                                              
                                                if( $ele -like $op ){
                                                    $operador = $ele
                                                    $achouOp=$true
                                                    break
                                                }
                                            }
                                            if( $operador ) {break}
                                        } 
                                    }else{
                                        #nao eh vetor
                                        forEach($col in $elemDaLinha){ 
                                            $ele = $col                                   
                                            if( $col.count -ne 1 ){
                                                $ele = Limpa-String -tabela $col.replace("CAST('", "").Replace("'","")
                                            }        
                                                                    
                                            if( $ele -like "" ){ continue }   
                                            forEach($op in $listaOperadores){ 
                                                                                
                                                if( $ele -like $op ){
                                                    $operador = $ele
                                                    $achouOp=$true
                                                    break
                                                }
                                            }
                                            if( $operador ) {break}
                                        }
                                    }
                                          
                                    if( $operador ) {

                                        $ordem++

                                        $caminho  = $arquivo.DirectoryName
                                        $arquivoC = $arquivo.BaseName + $arquivo.Extension
                                        $ordemS   = [string]$ordem
                                        $tabela   = $tabela.ToUpper()
                                        $operador = $operador.ToUpper()
                                        $criacao  = $arquivo.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        $edicao   = $arquivo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        $criadorArquivo = if( (Get-ACL ($arquivo.FullName)).Owner -match "\\" ){ (Get-ACL ($arquivo.FullName)).Owner.Split("\")[1].ToString() }else{ "DESCONHECIDO" }
                                         
                                        $insereArquivo += "INSERT INTO CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS
                                            ('$caminho', '$arquivoC', 1, '$ordemS', '$tabela', '$operador', Current_Date, '$criacao', '$edicao', '$criadorArquivo');`n"

                                        break
                                    }else{
                                        #vai para a linha de cima
                                        #codigo copiado do de baixo
                                        #nao achou operador na mesma linha
                                        for($cpLinha=$indice; $cpLinha -ge 0; $cpLinha--){

                                        #$cpLinha=5
                                            if( $conteudoArquivo[$cpLinha] -ne $null ){

                                                if( $conteudoArquivo[$cpLinha].Split(' ').Split("`t").Count -lt 1 ){
                                                    #qlq coisa comenada
                                                }else{    
                                                    $indice--

                                                    $qtdColunas = $conteudoArquivo[$indice].Split(' ').Split("`t").Count
                                                    if( $qtdColunas -eq 0){
                                                        $qtdColunas = $conteudoArquivo[$indice].Split('`n').Count
                                                    }
                                                    $teste2 = $conteudoArquivo[$qtdColunas-1]
                                                    $teste = $conteudoArquivo[$qtdColunas] + "teste"
                                                    $vetor = $conteudoArquivo[$qtdColunas].Split(' ').Split("`t")

                                                    $indice++
                                                    break
                                                }
                                            }else{
                                                continue
                                            }
                                        }
                                    }
                                }  ## fim laço ENCONTRAR comando
                                else{ ## fim IF nao achou operador nao linha
                                    ## não achou o operador na mesma linha. procura na linha acima
                                    #nao achou operador na mesma linha
                                    for($cpLinha=$indice; $cpLinha -ge 0; $cpLinha--){

                                    #$cpLinha=5
                                        if( $conteudoArquivo[$cpLinha] -ne $null ){

                                            if( $conteudoArquivo[$cpLinha].Split(' ').Split("`t").Count -lt 1 ){
                                                #qlq coisa comentada
                                                continue
                                            }else{    
                                                $indice--

                                                $qtdColunas = $conteudoArquivo[$indice].Split(' ').Split("`t").Count
                                                if( $qtdColunas -eq 0 ){
                                                    $qtdColunas = $conteudoArquivo[$indice].Split('`n').Count
                                                }

                                                $indice++
                                                break
                                            }
                                        }else{
                                            continue
                                        }
                                    }                        
                                    #####                                              
                                }               
                            }
                        }  ## fim if nome da tabela comentado
                    }  ## fim laço database encontrado na linha
                    #coloca MAIS UM BREAK AKI
                    if( $operador ) { $operador=""; break }  # caso o operador tenha sido encontrado pula para a próxima linha
            
                ##fim do laço do VETOR --pesquisa item por item procurando pelo operador

                }  ## fim laço linha do arquivo
                #$vetor
            }  ## fim if database encontrado
        #    Write-Host "line: " + $linha
        }  ## fim laço arquivo

        if($insereArquivo) {

            $insertSplitado = $insereArquivo.split(";")
            $total = $insertSplitado.count
            if( $total -gt 600 ){
                $metade = [math]::truncate($insertSplitado.count/2)

                $consultaInserir1 = $insertSplitado[0..($metade-1)]
                $joinArray1 = ""
                foreach($value in $consultaInserir1){ $joinArray1 += $value+";" }

                $consultaInserir2 = $insertSplitado[$metade..$total]
                $joinArray2 = ""
                foreach($value in $consultaInserir1){ $joinArray2 += $value+";" }

                Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Inserindo Split 1" -ForegroundColor Green
                Roda-SQL -SQL $joinArray1
                Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Inserindo Split 2" -ForegroundColor Green
                Roda-SQL -SQL $joinArray2
            }else{
                Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Inserindo" -ForegroundColor Green
                Roda-SQL -SQL $insereArquivo
            }

        } else {
            Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Arquivo sem tabelas" -ForegroundColor Yellow
        }
    }

    Write-Host (Get-Date).ToString("HH:mm:ss") "Coletando estatísticas"
    Roda-SQL -SQL (SQL4)

    Write-Host (Get-Date).ToString("HH:mm:ss") "Inativando arquivos inativos"
    $arquivosTabela = Roda-SQL -SQL (SQL5)
    $arquivosTotal = $arquivosTotal | Sort-Object FullName
	foreach($arquivoTabela in $arquivosTabela){
        $arquivoNome = [string]$arquivoTabela[0]
        $ind = 0
        $superior = $arquivosTotal.length-1
        $inferior = 0
        while($inferior -le $superior) {
            [int]$pivo = ($superior + $inferior) / 2
            $nomePivo = $arquivosTotal[$pivo].FullName
            if($arquivoNome -eq $nomePivo){
                $ind = 1
                break
            }
            if($arquivoNome -lt $nomePivo) {
                $superior = $pivo-1
            } else {
                $inferior = $pivo+1
            }
        }
        if($ind -eq 0){
            Roda-SQL -SQL (SQL6 -arquivo $arquivoNome)
        }
    }
    
    $texto = "Prezado,<br/><br/>Mapeamento de Tabelas concluído."
    Envia-Email -emails "enriqq3d@gmail.com;" -assunto "[E-mail Automático] 10 - Êxito - Mapeamento de Tabelas - $hoje" -texto $texto
    #Roda-SQL -SQL (SQL7 -tipo "Êxito" -data $dataInicio)
    Write-Host (Get-Date).ToString("HH:mm:ss") "Processamento finalizado com sucesso." -ForegroundColor Green    

} catch {
    #Se houve erro no processamento, envia e-mail com o log de erro
    $erro = 1
    Write-Host (Get-Date).ToString("HH:mm:ss") "Erro no processamento. Enviando email com log."
    $log = $dirProcesso + "Log\Mapeamento_Tabelas_" + (GET-DATE -format "yyyy-MM-dd_HH-mm").toString() + ".log"
    Write-Host (Get-Date).ToString("HH:mm:ss") $_.InvocationInfo.PositionMessage -ForegroundColor Red
    Write-Host (Get-Date).ToString("HH:mm:ss") $_.Exception.GetType().FullName -ForegroundColor Red
    Write-Host (Get-Date).ToString("HH:mm:ss") $_.Exception.Message -ForegroundColor Red
    $_.InvocationInfo.PositionMessage > $log
    $_.Exception.GetType().FullName >> $log
    $_.Exception.Message >> $log
    $arquivo.FullName >> $log
    $qtdColunas >> $log
    $teste >> $log
    $teste2 >> $log
    $texto = "Prezado,<br/><br/>Erro no processamento.<br/>Verifique o arquivo de log: $log"
    #Envia-Email -emails "enriqq3d@gmail.com" -assunto "[E-mail Automático] 10 - Erro - Mapeamento de Tabelas - $hoje" -texto $texto
    #Roda-SQL -SQL (SQL7 -tipo "Erro" -data $dataInicio)
}
finnally{
    $conn.close()
}