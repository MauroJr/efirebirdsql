%%% The MIT License (MIT)
%%% Copyright (c) 2016 Hajime Nakagami<nakagami@gmail.com>

-record(column, {
    name :: binary(),
    type :: atom(),
    size :: -1 | pos_integer(),
    modifier :: -1 | pos_integer()
}).

-record(statement, {
    handle :: binary(),
    trans_handle :: binary,
    name :: string(),
    columns :: [#column{}],
    types :: [atom()]
}).

-record(error, {
    code :: binary()
}).
