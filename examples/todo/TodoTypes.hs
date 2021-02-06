{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

module TodoTypes where

import Control.Lens.TH
import Data.Default
import Data.Text (Text)

import Monomer

data TodoType
  = Home
  | Work
  deriving (Eq, Show, Enum)

data TodoStatus
  = Pending
  | Done
  deriving (Eq, Show, Enum)

data Todo = Todo {
  _todoType :: TodoType,
  _status :: TodoStatus,
  _description :: Text
} deriving (Eq, Show)

instance Default Todo where
  def = Todo {
    _todoType = Home,
    _status = Pending,
    _description = ""
  }

data TodoAction
  = TodoNone
  | TodoAdding
  | TodoEditing Int
  deriving (Eq, Show)

data TodoModel = TodoModel {
  _todos :: [Todo],
  _activeTodo :: Todo,
  _action :: TodoAction
} deriving (Eq, Show, WidgetModel)

data TodoEvt
  = TodoInit
  | TodoNew
  | TodoAdd
  | TodoEdit Int Todo
  | TodoSave Int
  | TodoDelete Int
  | TodoCancel
  deriving (Eq, Show)

makeLenses 'TodoModel
makeLenses 'Todo

todoTypes :: [TodoType]
todoTypes = enumFrom (toEnum 0)

todoStatuses :: [TodoStatus]
todoStatuses = enumFrom (toEnum 0)
