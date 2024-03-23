<hr/>

# Laboratório PostgreSQL & PL/pgSQL

O PostgreSQL&copy; é um poderoso sistema de gerenciamento de banco de dados relacional de código aberto. Ele também é conhecido 
por sua confiabilidade, extensibilidade e conformidade com os padrões SQL. Ele suporta uma ampla variedade de tipos de dados, 
incluindo tipos personalizados, e oferece recursos avançados como transações ACID, replicação, indexação avançada e 
suporte a linguagens procedurais, como a PL/pgSQL que é específica do PostgreSQL&copy; e baseada em SQL. Ela foi 
projetada para auxiliar nas tarefas de programação dentro do PostgreSQL&copy;, incorporando características procedurais 
que facilitam o controle de fluxo de programas. Nós iremos arranhar um pouco a sua superfície, e ter uma idéia do que
ela é capaz.

Em minha abordagem utilizarei um container Docker&copy; e a documentação oficial, pode ser consultada neste 
[link](https://docs.docker.com/desktop/install/windows-install/) para auxiliar a instalação em diferentes plataformas. A idéia de utilizar container, é ter um laboratório
que possa ser manipulado sem riscos.

Não há necessidade de se possuir um grande conhecimento em Docker&copy; para isso. Basta editar um arquivo *.yaml* como 
abaixo:
```yaml
version: "3.8"
services:
  postgres:
    container_name: postgres
    image: postgres:16.1
    restart: always
    environment:
      - POSTGRES_DB=laboratorio
      - POSTGRES_USER=estudante
      - POSTGRES_PASSWORD=212223
      - TZ=America/Sao_Paulo
    ports:
      - "5430:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data/

  pgadmin4:
    container_name: pgadmin4
    image: dpage/pgadmin4:8.4
    restart: always
    environment:
      - PGADMIN_DEFAULT_EMAIL=estudante@email.com
      - PGADMIN_DEFAULT_PASSWORD=212223
    ports:
      - "5050:80"

volumes:
  pgdata:
```
Se desejar alterar os dados contidos no exemplo, fique a vontade, do contrário, abra um terminal na pasta onde o arquivo 
está salvo e digite o comando a seguir: 
```shell
docker-compose up -d 
```
Desta forma teremos inclusive a ferramenta pgAdmin4 para realizarmos as nossas consultas e manipulações. Você poderá
acessar o pgAdmin, abrindo o seu browser em http://localhost:5050. Realize o login com o usuário e senha definidos em 
PGADMIN_DEFAULT_EMAIL e PGADMIN_DEFAULT_PASSWORD. 

Será necessário definir o servidor do banco de dados, neste [link](markdown/pgadmin.md) eu vou deixar um pequeno tutorial de como fazer isso. 

## Tabelas

Como proposta para este exercício, vamos criar três tabelas e estabeleceremos relações entre elas. Teremos uma 
tabela principal (*estoque*) e outras duas secundárias (*produtos* e *vendas*). As tabelas *produtos* e *vendas*, 
se relacionarão diretamente com o estoque, mas indiretamente entre si. Vamos começar.
```sql
CREATE TABLE estoque (
    produto VARCHAR(255) PRIMARY KEY,
    quantidade INTEGER,
    custo NUMERIC(11, 2),
    lucro NUMERIC,
    data DATE
);

CREATE TABLE produtos (
    nome VARCHAR(255) PRIMARY KEY,
    preco NUMERIC(11, 2),
    FOREIGN KEY (nome)
        REFERENCES estoque(produto)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE vendas (
    produto VARCHAR(255),
    data DATE DEFAULT CURRENT_DATE,
    quantidade INTEGER,
    valor NUMERIC(11, 2),
    ref VARCHAR(255),
    FOREIGN KEY (ref)
        REFERENCES estoque(produto)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);
```

Perceba que ao estabelecermos um relacionamento entre duas chaves primárias, como ocorre entre *estoque* 
e *produtos*, estamos criando uma relação de um para um(1:1 ou one-to-one), pois, ambas possui restrição de unicidade
em suas respectivas colunas. Já na tabela *vendas*, a relação estabelecida diretamente com a tabela *estoque*, e 
indiretamente com a tabela *produtos*, é de um para muitos (1:N ou ono-to-many). Desta forma,
poderemos ter vários registros em vendas, relacionados a um único produto.

## Criando lógicas reutilizáveis

 As linguagens procedurais para banco de dados, além de facilitarem o fluxo de programas, como dito anteriormente, também 
permitem que, ao elaborarmos uma lógica, ela possa ser reutilizada em outros trechos de código. Vamos então criar uma lógica
 para calcular o preço final do produto a partir da quantidade de produtos adquiridos para estoque, o custo total da aquisição 
 e a margem de lucro estabelecida.

```sql
CREATE OR REPLACE FUNCTION calcular_preco(quantidade INTEGER, custo NUMERIC, lucro NUMERIC)
    RETURNS NUMERIC AS $$
        DECLARE
            preco NUMERIC;
        BEGIN
            preco :=  custo / quantidade;
            preco := preco + (preco * (lucro / 100));
            RETURN ROUND(preco, 2);
        END;
    $$ LANGUAGE plpgsql;
```

Também vamos desenvolver uma função para calcular o valor de uma venda com base na quantidade vendida e no desconto
atribuído.

```sql
CREATE OR REPLACE FUNCTION calcular_valor_da_venda(preco NUMERIC, quantidade INTEGER, desconto NUMERIC DEFAULT NULL)
    RETURNS NUMERIC AS $$
        DECLARE
            valor NUMERIC;
        BEGIN
            IF desconto IS NOT NULL
                THEN
                valor := preco - (preco * (desconto / 100));
                valor := valor * quantidade;
            ELSE
                valor := preco * quantidade;
            END IF;
            RETURN ROUND(valor, 2);
        END;
    $$ LANGUAGE plpgsql;
```

Ótimo! Agora temos códigos que nos auxiliarão mais adiante. Perceba que na função calcular_valor_da_venda(), temos um 
parâmetro que declaramos com um valor DEFAULT NULL e como utilizamos ele para realizar calculos diferentes. 

Vamos calcular o preço final de 100 unidades de um produto, com o custo de 100 reais e com uma margem de lucro de 50% por
unidade:

```shell
laboratorio=# SELECT * FROM calcular_preco(100, 100, 50);
 calcular_preco
----------------
           1.50
(1 registro)
```

Agora, vamos calcular o valor da venda de 2 unidade de um produto com o preço de 1,50 reais, primeiramente, sem desconto 
e em seguida com 5% de desconto:

```shell
laboratorio=# SELECT * FROM calcular_valor_da_venda(1.5, 2);
 calcular_valor_da_venda
-------------------------
                    3.00
(1 registro)
```

```shell
laboratorio=# SELECT * FROM calcular_valor_da_venda(1.5, 2, 5);
 calcular_valor_da_venda
-------------------------
                    2.85
(1 registro)
```

Tudo funcionando até aqui, vamos seguir adiante.

## Triggers & funções triggers

Agora vamos automatizar algumas ações em nosso banco de dados. Começaremos com a inserção de um produto na tabela
*produtos* a partir do registro dele no estoque. Para isso vamos utilizar funções que serão disparadas por gatilhos.
Também vamos implementar a mesma lógica para *vendas*. Quando uma venda for realizada, a quantidade de produtos vendidos
será retirada do estoque. Vamos começar com o primeiro cenário.

```sql
CREATE OR REPLACE FUNCTION criar_produto ()
    RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO produtos (nome, preco)
                VALUES (NEW.produto, calcular_preco(NEW.quantidade, NEW.custo, NEW.lucro));
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_produto
    AFTER INSERT ON estoque
    FOR EACH ROW
    EXECUTE FUNCTION criar_produto();
```

Com estes dispositivos, toda a vez que inserirmos um novo produto no *estoque*, ele será registrado em *produtos*, observe
como utilizamos a nossa função **calcular_preco()** para deixar o nosso código mais claro.

Para o cenário seguinte, precisaremos realizar um UPDATE em *estoque* a partir da inserção de dados em *vendas*, mas isso
não representará uma dificuldade maior, observe:

```sql
CREATE OR REPLACE FUNCTION atualizar_quantidade_em_estoque()
    RETURNS TRIGGER AS $$
        BEGIN
            UPDATE estoque
                SET quantidade = quantidade - NEW.quantidade
                WHERE produto = NEW.ref;
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_quantidade_em_estoque
    AFTER INSERT ON vendas
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_quantidade_em_estoque();
```

Pronto, lógica implementada, vamos em frente.

## Tratamento de exceções

Definimos em nossa tabela *estoque* que a coluna 'produto' seria uma chave primária. Isso confere a ela uma unicidade, 
de modo que não haverá outro registro com o mesmo conteúdo na coluna em questão, em nossa tabela *produtos*. Porém, 
se o programa que for utilizar o nosso banco de dados, tentar realizar a operação descrita acima, um erro será emitido 
pelo nosso banco. Se imaginarmos que esse erro poderá gerar problemas de execução mais a frente, seria inteligente de nossa
parte, tomarmos alguma precaução desde agora. Por isso, ao invés de permitir que uma exceção seja levantada, vamos 
retornar um valor que possa ser computado, como um booleano, por exemplo. 

```sql
CREATE OR REPLACE FUNCTION registrar_produto_no_estoque(_produto VARCHAR, _quantidade INTEGER, _custo NUMERIC, _lucro NUMERIC, _data DATE)
    RETURNS BOOLEAN AS $$
        BEGIN
            INSERT INTO estoque (produto, quantidade, custo, lucro, data)
                VALUES (_produto, _quantidade, _custo, _lucro, _data);
            RETURN TRUE;
        EXCEPTION
            WHEN others
                THEN
                    RETURN FALSE;
        END;
    $$ LANGUAGE plpgsql;
```

Agora podemos, inclusive, realizar alguns testes para verificar se nosso gatilho está funcionando.

```shell
laboratorio=# SELECT * FROM registrar_produto_no_estoque('abacate', 100, 100, 10, '2024-03-21');
 registrar_produto_no_estoque
------------------------------
 true
(1 registro)
```

Se tentarmos uma inserção de um produto com o mesmo nome, receberemos um *false*.

```shell
laboratorio=# SELECT * FROM registrar_produto_no_estoque('abacate', 100, 100, 10, '2024-03-21');
 registrar_produto_no_estoque
------------------------------
 false
(1 registro)
```

Somente um registro foi gerado em *estoque*.

```shell
laboratorio=# SELECT * FROM estoque;
 produto | quantidade | custo  | lucro |    data
---------+------------+--------+-------+------------
 abacate |        100 | 100.00 |    10 | 2024-03-21
(2 registros)

```

Também foi criado um registro em *produtos*.

```shell
laboratorio=# SELECT * FROM produtos;
  nome   | preco
---------+-------
 abacate |  1.10
(2 registros)
```

## Declarando e utilizando variáveis

Precisamos realizar alguns registros em vendas para testarmos se a lógica que implementamos anteriormente está funcionando.
Lembre-se que, toda a vez que uma venda for registrada, a quantidade de produto vendida, será decrementada do estoque. Porém,
não queremos que a venda seja registrada se não houver uma quantidade de produto suficiente para cobrir o pedido. Uma forma
de realizar esta verificação seria realizar uma busca pelo produto no estoque, verificar se a quantidade disponível é suficiente 
para cobrir a venda e atribuir um valor booleano em uma variável que servirá de condição para a realização do registro em
*vendas*. Vejamos como podemos fazer isso:

```sql
CREATE OR REPLACE FUNCTION registrar_venda(_produto VARCHAR, _quantidade INTEGER, desconto NUMERIC DEFAULT NULL)
    RETURNS BOOLEAN AS $$
        DECLARE
            existe BOOLEAN;
            _preco NUMERIC;
        BEGIN
            SELECT p.preco, TRUE INTO _preco, existe
                FROM produtos p
                JOIN estoque e ON e.produto = p.nome
                WHERE e.produto = _produto AND e.quantidade >= _quantidade;
            IF existe
                THEN
                    INSERT INTO vendas (produto, quantidade, valor, ref)
                        VALUES (
                            _produto,
                            _quantidade,
                            calcular_valor_da_venda(_preco, _quantidade, desconto),
                            _produto
                        );
                    RETURN TRUE;
            END IF;
            RETURN FALSE;
        END;
    $$ LANGUAGE plpgsql;
```

Nesta função, recebemos como parâmetros, o produto, a quantidade e o desconto, pode ou não ser atribuído. 
Declaramos duas variáveis onde armazenaremos os dados referentes ao produto de que se trata a venda. Realizamos uma 
consulta e utilizamos a cláusula INTO para fazer as atribuições que necessitamos. Como temos tabelas que se relacionam 
entre si (*estoque* e *produtos*), fazemos um JOIN entre as duas para estabelecermos uma correspondência entre os 
atributos que recebemos e os dados que temos em nosso banco de dados. Em seguida, condicionamos o registro em vendas em 
bloco IF, retornando TRUE se a ação for executada com sucesso ou FALSE caso o bloco if não seja executado.

Talvez esta seja a mais complicada função entre os nossos execícios. Vamos realizar alguns testes para verificar se temos
tudo funcionando como esperamos. 

Primeiro vamos realizar uma consulta no produto para verificarmos seus dados em estoque.

```shell
laboratorio=# SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco FROM estoque as e JOIN produtos as p ON e.produto = p.nome WHERE produto = 'laranja';
 produto | quantidade | custo  | lucro | preco
---------+------------+--------+-------+-------
 laranja |        464 | 750.00 |    35 |  2.03
(1 registro)
```

Agora, vamos vender 24 laranjas, sem desconto:

```shell
laboratorio=# SELECT * FROM registrar_venda('laranja', 24);
 registrar_venda
-----------------
 true
(1 registro)
```

Em seguida, a mesma venda, mas com 7% de desconto:

```shell
laboratorio=# SELECT * FROM registrar_venda('laranja', 24, 7);
 registrar_venda
 -----------------
 true
(1 registro)
```

E a quantidade de laranja em estoque foi atualizada como esperávamos.

```shell
laboratorio=# SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco FROM estoque as e JOIN produtos as p ON e.produto = p.nome WHERE produto = 'laranja';
 produto | quantidade | custo  | lucro | preco
---------+------------+--------+-------+-------
 laranja |        416 | 750.00 |    35 |  2.03
(1 registro)
```

Também podemos verificar que o desconto por unidade foi aplicado na segunda venda.

```shell
laboratorio=# SELECT p.nome as "produto", v.data, v.quantidade, v.valor FROM vendas as v JOIN produtos as p ON v.produto = p.nome WHERE v.produto = 'laranja';
 produto |    data    | quantidade | valor
---------+------------+------------+-------
 laranja | 2024-03-22 |         24 | 48.72
 laranja | 2024-03-22 |         24 | 45.31
(2 registros)
```

## Deixando de digitar o mesmo código toda a vez

Nos nossos testes anteriores, utilizamos consultas que possuem um código bem extenso. Precisamos colocar essas consultas
em uma função para não termos que digitar tudo de novo, o tempo todo.

```sql
CREATE OR REPLACE FUNCTION selecionar_produto_em_estoque(_produto VARCHAR DEFAULT NULL)
    RETURNS TABLE (produto VARCHAR, quantidade INTEGER, custo NUMERIC, lucro NUMERIC, preco NUMERIC) AS $$
        BEGIN
            IF _produto IS NOT NULL
                THEN
                    RETURN QUERY
                        SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
                            FROM estoque e
                            JOIN produtos p
                            ON e.produto = p.nome
                        WHERE e.produto = _produto;
            ELSE
                RETURN QUERY
                    SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
                        FROM estoque e
                        JOIN produtos p
                        ON e.produto = p.nome
                    ORDER BY e.produto;
            END IF;
        END;
    $$ LANGUAGE plpgsql;
```

Agora podemos realizar nossa consulta em todos os produtos, ou pelo nome, apenas chamando a função e passando ou não
o nome do produto que desejamos consultar: 

```shell
laboratorio=# SELECT * FROM selecionar_produto_em_estoque();
 produto | quantidade | custo  | lucro | preco
---------+------------+--------+-------+-------
 abacate |         91 | 100.00 |    10 |  1.10
 banana  |         84 | 100.00 |    10 |  1.10
 laranja |        392 | 750.00 |    35 |  2.03
(3 registros)
```
```shell
laboratorio=# SELECT * FROM selecionar_produto_em_estoque('laranja');
 produto | quantidade | custo  | lucro | preco
---------+------------+--------+-------+-------
 laranja |        392 | 750.00 |    35 |  2.03
(1 registro)
```

Seguindo o mesmo padrão lógico, vamos deixar implementado algumas consultas para as vendas de produtos ou de um produto,
e uma consulta para o produto disponível a venda, tendo em vista que o comprador não precisa ter informações como custo, 
margem de lucro, etc.

```sql
CREATE OR REPLACE FUNCTION selecionar_vendas(_produto VARCHAR DEFAULT NULL)
    RETURNS TABLE (produto VARCHAR, data DATE, quantidade INTEGER, valor NUMERIC) AS $$
        BEGIN
            IF _produto IS NOT NULL
                THEN
                    RETURN QUERY
                        SELECT v.produto, v.data, v.quantidade, v.valor
                            FROM vendas v
                        WHERE v.ref = _produto
                            ORDER BY v.data DESC;
            ELSE
                RETURN QUERY
                    SELECT v.produto, v.data, v.quantidade, v.valor
                        FROM vendas v
                        ORDER BY v.produto, v.data DESC;
            END IF;
        END;
    $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION selecionar_produto_para_venda(_produto VARCHAR DEFAULT NULL)
    RETURNS TABLE (produto VARCHAR, preco NUMERIC) AS $$
        BEGIN
            IF _produto IS NOT NULL
                THEN
                    RETURN QUERY
                    SELECT p.nome, p.preco
                        FROM produtos p
                    WHERE p.nome = _produto ORDER BY p.nome;
            ELSE
                RETURN QUERY
                    SELECT p.nome, p.preco FROM produtos p ORDER BY p.nome;
            END IF;
        END;
    $$ LANGUAGE plpgsql;
```

## Sem UPDATE não tem CRUD

Precisamos realizar algumas atualizações em nosso estoque. Como estamos utilizando a coluna 'produto' como chave primária,
e referenciamos ela nas demais tabelas com uma cláusula CASCADE para atualização, não precisamos nos preocupar com a atualização
do nome do produto. A quantidade de produtos em estoque não reflete diretamente ao preço do produto, mas o custo total e 
a margem de lucro sim. Vamos implementar uma função que permita atualizar vários atributos de nosso estoque, inclusive
o preço de revenda do produto. Vamos utilizar parâmetros pré-definidos para que nossa função possa ter uma dinamicidade
maior.

```sql
CREATE OR REPLACE FUNCTION atualizar_dados_estoque_e_produto(_produto VARCHAR, _quantidade INTEGER DEFAULT NULL, _custo NUMERIC DEFAULT NULL, _lucro NUMERIC DEFAULT NULL)
    RETURNS TABLE (prod VARCHAR, qtd INTEGER, cst NUMERIC, lcr NUMERIC, prc NUMERIC) AS $$
        DECLARE
            custo NUMERIC;
            lucro NUMERIC;
            quantidade INTEGER;
        BEGIN
            IF _quantidade IS NOT NULL
                THEN
                    UPDATE estoque
                        SET quantidade = _quantidade
                    WHERE produto=_produto;
            END IF;
            IF _custo IS NOT NULL
                THEN
                    SELECT e.quantidade, e.lucro INTO quantidade, lucro
                        FROM estoque e WHERE e.produto = _produto;
                    UPDATE estoque
                        SET custo = _custo
                    WHERE produto = _produto;
                    UPDATE produtos
                        SET preco = calcular_preco(quantidade, _custo, lucro)
                    WHERE nome = _produto;
            END IF;
            IF _lucro IS NOT NULL
                THEN
                    SELECT e.quantidade, e.custo INTO quantidade, custo
                        FROM estoque e WHERE e.produto = _produto;
                    UPDATE estoque
                        SET lucro = _lucro
                    WHERE produto = _produto;
                    UPDATE produtos
                        SET preco = calcular_preco(quantidade, custo, _lucro)
                    WHERE nome = _produto;
            END IF;
            RETURN QUERY
                SELECT * FROM selecionar_produto_em_estoque(_produto) as s;
        END;
    $$ LANGUAGE plpgsql;
```

Vamos realizar algumas atualizações no nosso abacate.

```shell
laboratorio=# SELECT * FROM selecionar_produto_em_estoque('abacate');
 produto | quantidade | custo  | lucro | preco
---------+------------+--------+-------+-------
 abacate |        100 | 100.00 |    10 |  1.10
(1 registro)
```

Vamos atualizar a quantidade e ver se temos algum impacto.

```shell
laboratorio=# SELECT * FROM atualizar_dados_estoque_e_produto('abacate', 200);
  prod   | qtd |  cst   | lcr | prc
---------+-----+--------+-----+------
 abacate | 200 | 100.00 |  10 | 1.10
(1 registro)
```

Agora podemos experimentar atualizar o custo do produto.

```shell
laboratorio=# SELECT * FROM atualizar_dados_estoque_e_produto('abacate', _custo := 150);
  prod   | qtd |  cst   | lcr | prc
---------+-----+--------+-----+------
 abacate | 200 | 150.00 |  10 | 0.83
(1 registro)
```

A atualização do custo gerou o resultado esperado. Vamos experimentar a margem de lucro.

```shell
laboratorio=# SELECT * FROM atualizar_dados_estoque_e_produto('abacate', _lucro := 25 );
  prod   | qtd |  cst   | lcr | prc
---------+-----+--------+-----+------
 abacate | 200 | 150.00 |  25 | 0.94
(1 registro)
```

Tudo está funcionando como o esperado. Observe como podemos chamar os parâmetros da função de forma independente. 
Vale ressaltar que a escolha por uma sequência de blocos IFs ao invés de um bloco IF ELSIF ELSE, é proposital. Desta
forma, conseguimos atualizar todos os parâmetros de uma única vez.

```shell
laboratorio=# SELECT * FROM atualizar_dados_estoque_e_produto('abacate', 100, 100, 5 );
  prod   | qtd |  cst   | lcr | prc
---------+-----+--------+-----+------
 abacate | 100 | 100.00 |   5 | 1.05
(1 registro)
```

## E o DELETE

Nossas tabelas possuem relações específicas e uma ação de excluir um registro, deve partir do estoque e repercutir nas demais. 
Definimos que o DELETE em produtos será executado em modo CASCADE, mas o mesmo não irá acontecer em vendas. Isso porque, 
mesmo que o produto não seja mais vendido na "lojinha", poderia ser interessante manter os registros de vendas.

A exclusão de um registro poderiam ser feito por uma simples query SQL, porém, como iremos utilizar este banco de dados
em aplicações futuras, vamos criar uma função para realizar o DELETE, até mesmo, para não quebrarmos o padrão que estamos utilizando.

```sql
CREATE OR REPLACE FUNCTION deletar_produto(_product VARCHAR)
    RETURNS BOOLEAN AS $$
        DECLARE
            existe BOOLEAN;
        BEGIN
            SELECT TRUE INTO existe FROM estoque WHERE produto = _product;
            IF existe
                THEN
                    DELETE FROM estoque WHERE produto = _product;
                    RETURN TRUE;
            ELSE
                RETURN FALSE;
            END IF;
        END;
    $$ LANGUAGE plpgsql;
```

Vamos realizar os testes para verificar como a ação de excluir um produto se propaga pelo nosso banco de dados.
Primeiramente, vamos observar os registros do produto em nossas tabelas de *estoque*, *produtos* e *vendas*.

```shell
laboratorio=# SELECT * FROM selecionar_produto_em_estoque();
 produto | quantidade | custo  | lucro | preco
---------+------------+--------+-------+-------
 abacate |        279 | 455.00 |    22 |  1.85
 banana  |        226 | 265.00 |    25 |  1.33
 laranja |        250 | 440.00 |    15 |  2.02
 morango |        602 | 832.00 |    45 |  1.86
 tomate  |        500 | 732.00 |    25 |  1.83
(5 registros)
```

```shell
laboratorio=# SELECT * FROM selecionar_produto_para_venda();
 produto | preco
---------+-------
 abacate |  1.85
 banana  |  1.33
 laranja |  2.02
 morango |  1.86
 tomate  |  1.83
(5 registros)
```

```shell
laboratorio=# SELECT * FROM selecionar_vendas();
 produto |    data    | quantidade | valor
---------+------------+------------+-------
 abacate | 2024-03-23 |          3 |  5.55
 abacate | 2024-03-23 |          8 | 14.80
 abacate | 2024-03-23 |          4 |  7.40
 abacate | 2024-03-23 |          6 | 11.10
 banana  | 2024-03-23 |         18 | 22.26
 banana  | 2024-03-23 |          6 |  7.98
 morango | 2024-03-23 |         20 | 37.20
 morango | 2024-03-23 |          8 | 14.14
 morango | 2024-03-23 |          8 | 14.88
 morango | 2024-03-23 |         12 | 22.32
(10 registros)
```

Estas são os registros em nossas três tabelas. O nosso estoque, os produtos à venda e todas as vendas realizadas.
Vamos deletar o morango, e verificar se ele será excluído da tabela *produtos*, mas seus registros de vendas serão mantidos.

```shell
laboratorio=# SELECT * FROM deletar_produto('morango');
 deletar_produto
-----------------
 true
(1 registro)
```

Vamos ver se temos o morango em estoque e disponível para venda.

```shell
laboratorio=# SELECT * FROM selecionar_produto_em_estoque();
 produto | quantidade | custo  | lucro | preco
---------+------------+--------+-------+-------
 abacate |        279 | 455.00 |    22 |  1.85
 banana  |        226 | 265.00 |    25 |  1.33
 laranja |        250 | 440.00 |    15 |  2.02
 tomate  |        500 | 732.00 |    25 |  1.83
(4 registros)
```

```shell
laboratorio=# SELECT * FROM selecionar_produto_para_venda();
 produto | preco
---------+-------
 abacate |  1.85
 banana  |  1.33
 laranja |  2.02
 tomate  |  1.83
(4 registros)
```

Não temos mais o morango disponível, porém, ainda mantemos os seus registros de venda.

```shell
laboratorio=# SELECT * FROM selecionar_vendas();
 produto |    data    | quantidade | valor
---------+------------+------------+-------
 abacate | 2024-03-23 |          4 |  7.40
 abacate | 2024-03-23 |          3 |  5.55
 abacate | 2024-03-23 |          8 | 14.80
 abacate | 2024-03-23 |          6 | 11.10
 banana  | 2024-03-23 |          6 |  7.98
 banana  | 2024-03-23 |         18 | 22.26
 morango | 2024-03-23 |         20 | 37.20
 morango | 2024-03-23 |         12 | 22.32
 morango | 2024-03-23 |          8 | 14.88
 morango | 2024-03-23 |          8 | 14.14
(10 registros)
```

Se realizarmos uma consulta generalizada em vendas, veremos que a coluna que faz referência ao estoque, está com valores 
nulos.

```shell
laboratorio=# SELECT * FROM vendas;
 produto |    data    | quantidade | valor |   ref
---------+------------+------------+-------+---------
 banana  | 2024-03-23 |          6 |  7.98 | banana
 banana  | 2024-03-23 |         18 | 22.26 | banana
 abacate | 2024-03-23 |          8 | 14.80 | abacate
 abacate | 2024-03-23 |          6 | 11.10 | abacate
 abacate | 2024-03-23 |          4 |  7.40 | abacate
 abacate | 2024-03-23 |          3 |  5.55 | abacate
 morango | 2024-03-23 |         20 | 37.20 |
 morango | 2024-03-23 |         12 | 22.32 |
 morango | 2024-03-23 |          8 | 14.88 |
 morango | 2024-03-23 |          8 | 14.14 |
(10 registros)
```

## Concluindo

Ufa!

Foi um caminho longo até aqui, mas acho que temos uma base de dados boa para nossas experiências futuras.
Nossos próximos passos consistirão em desenvolver aplicações que consumam o banco de dados que acabamos de criar.

Até lá!

<hr/>