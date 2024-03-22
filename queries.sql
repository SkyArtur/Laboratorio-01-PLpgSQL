/*---------------------------------------------------------------------------------------------------------------------
                                    EXCLUSÕES
---------------------------------------------------------------------------------------------------------------------*/

DROP TABLE produtos;
DROP TABLE vendas;
DROP TABLE estoque;

/*---------------------------------------------------------------------------------------------------------------------
                                    TABELAS
---------------------------------------------------------------------------------------------------------------------*/

CREATE TABLE estoque (
    produto VARCHAR(255) UNIQUE NOT NULL PRIMARY KEY,
    quantidade INTEGER,
    custo NUMERIC(11, 2),
    lucro NUMERIC,
    data DATE
);

CREATE TABLE produtos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR,
    preco NUMERIC(11, 2),
    FOREIGN KEY (nome)
        REFERENCES estoque(produto)
        ON DELETE CASCADE
);

CREATE TABLE vendas (
    produto INTEGER NOT NULL,
    data DATE DEFAULT CURRENT_DATE,
    quantidade INTEGER,
    valor NUMERIC(11, 2),
    FOREIGN KEY (produto)
        REFERENCES produtos(id)
        ON DELETE CASCADE
);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO TRIGGER criar_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION criar_produto ()
    RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO produtos (nome, preco)
                VALUES (NEW.produto, calcular_preco(NEW.quantidade, NEW.custo, NEW.lucro));
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

/*---------------------------------------------------------------------------------------------------------------------
                                    TRIGGER trigger_criar_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE TRIGGER trigger_create_produto
    AFTER INSERT ON estoque
    FOR EACH ROW
    EXECUTE FUNCTION criar_produto();

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO calcular_preco
---------------------------------------------------------------------------------------------------------------------*/

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

/*########           TESTES           ########*/
SELECT * FROM calcular_preco(100, 100, 10);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_produto_no_estoque
---------------------------------------------------------------------------------------------------------------------*/

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

/*########           TESTES           ########*/
SELECT * FROM registrar_produto_no_estoque('banana', 100, 100, 10, '2024-03-21');

SELECT * FROM estoque;

SELECT * FROM produtos;

SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
    FROM estoque as e
    JOIN produtos as p
    ON e.produto = p.nome;

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_produto_no_estoque
---------------------------------------------------------------------------------------------------------------------*/