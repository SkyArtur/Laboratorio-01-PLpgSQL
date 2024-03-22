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
);

CREATE TABLE vendas (
    produto VARCHAR(255) NOT NULL,
    data DATE DEFAULT CURRENT_DATE,
    quantidade INTEGER,
    valor NUMERIC(11, 2),
    FOREIGN KEY (produto)
        REFERENCES estoque(produto)
        ON DELETE CASCADE
);

```

Perceba que ao estabelecermos um relacionamento entre duas chaves primárias, como ocorre entre *estoque* 
e *produtos*, estamos criando uma relação de um para um(1:1 ou one-to-one), pois, ambas possui restrição de unicidade
em suas respectivas colunas. Já na tabela *vendas*, a relação estabelecida diretamente com a tabela *estoque*, e 
indiretamente com a tabela *produtos*, é de um para muitos (1:N ou ono-to-many). Veja que mesmo utilizando a 
coluna 'produto' como uma chave estrangeira, a única restrição que colocamos para ela é de não nulidade. Desta forma,
poderemos ter vários registros em vendas, relacionados a um único produto.

## Criando uma lógica reutilizável
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
Muito simples.

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
                WHERE produto = NEW.produto;
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_quantidade_em_estoque
    AFTER INSERT ON vendas
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_quantidade_em_estoque();
```
Pronto, lógica implementada, agora vamos seguir adiante.

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

Ótimo! Agora vamos realizar uma inserção em vendas para verificar a nossa lógica de atualização de estoque. Aqui nós vamos
trabalhar com variáveis e recuperação de dados. Vamos conhecer também o sinal de atribuição utilizado em PL/pgSQL.

<hr/>