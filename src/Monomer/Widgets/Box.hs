{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}

module Monomer.Widgets.Box (
  BoxCfg,
  box,
  box_,
  expandContent
) where

import Control.Applicative ((<|>))
import Control.Lens ((&), (^.), (.~))
import Data.Default
import Data.Maybe

import qualified Data.Sequence as Seq

import Monomer.Widgets.Container

import qualified Monomer.Lens as L

data BoxCfg s e = BoxCfg {
  _boxExpandContent :: Maybe Bool,
  _boxAlignH :: Maybe AlignH,
  _boxAlignV :: Maybe AlignV,
  _boxOnClick :: [e],
  _boxOnClickReq :: [WidgetRequest s],
  _boxOnClickEmpty :: [e],
  _boxOnClickEmptyReq :: [WidgetRequest s]
}

instance Default (BoxCfg s e) where
  def = BoxCfg {
    _boxExpandContent = Nothing,
    _boxAlignH = Nothing,
    _boxAlignV = Nothing,
    _boxOnClick = [],
    _boxOnClickReq = [],
    _boxOnClickEmpty = [],
    _boxOnClickEmptyReq = []
  }

instance Semigroup (BoxCfg s e) where
  (<>) t1 t2 = BoxCfg {
    _boxExpandContent = _boxExpandContent t2 <|> _boxExpandContent t1,
    _boxAlignH = _boxAlignH t2 <|> _boxAlignH t1,
    _boxAlignV = _boxAlignV t2 <|> _boxAlignV t1,
    _boxOnClick = _boxOnClick t1 <> _boxOnClick t2,
    _boxOnClickReq = _boxOnClickReq t1 <> _boxOnClickReq t2,
    _boxOnClickEmpty = _boxOnClickEmpty t1 <> _boxOnClickEmpty t2,
    _boxOnClickEmptyReq = _boxOnClickEmptyReq t1 <> _boxOnClickEmptyReq t2
  }

instance Monoid (BoxCfg s e) where
  mempty = def

instance CmbAlignLeft (BoxCfg s e) where
  alignLeft = def {
    _boxAlignH = Just ALeft
  }

instance CmbAlignCenter (BoxCfg s e) where
  alignCenter = def {
    _boxAlignH = Just ACenter
  }

instance CmbAlignRight (BoxCfg s e) where
  alignRight = def {
    _boxAlignH = Just ARight
  }

instance CmbAlignTop (BoxCfg s e) where
  alignTop = def {
    _boxAlignV = Just ATop
  }

instance CmbAlignMiddle (BoxCfg s e) where
  alignMiddle = def {
    _boxAlignV = Just AMiddle
  }

instance CmbAlignBottom (BoxCfg s e) where
  alignBottom = def {
    _boxAlignV = Just ABottom
  }

instance CmbOnClick (BoxCfg s e) e where
  onClick handler = def {
    _boxOnClick = [handler]
  }

instance CmbOnClickReq (BoxCfg s e) s where
  onClickReq req = def {
    _boxOnClickReq = [req]
  }

instance CmbOnClickEmpty (BoxCfg s e) e where
  onClickEmpty handler = def {
    _boxOnClickEmpty = [handler]
  }

instance CmbOnClickEmptyReq (BoxCfg s e) s where
  onClickEmptyReq req = def {
    _boxOnClickEmptyReq = [req]
  }

expandContent :: BoxCfg s e
expandContent = def {
  _boxExpandContent = Just True
}

box :: (WidgetModel s, WidgetEvent e) => WidgetNode s e -> WidgetNode s e
box managed = box_ managed def

box_
  :: (WidgetModel s, WidgetEvent e)
  => WidgetNode s e
  -> [BoxCfg s e]
  -> WidgetNode s e
box_ managed configs = makeInstance (makeBox config) managed where
  config = mconcat configs

makeInstance :: Widget s e -> WidgetNode s e -> WidgetNode s e
makeInstance widget managedWidget = defaultWidgetNode "box" widget
  & L.widgetInstance . L.focusable .~ False
  & L.children .~ Seq.singleton managedWidget

makeBox :: (WidgetModel s, WidgetEvent e) => BoxCfg s e -> Widget s e
makeBox config = widget where
  widget = createContainer def {
    containerHandleEvent = handleEvent,
    containerGetSizeReq = getSizeReq,
    containerResize = resize
  }

  handleEvent wenv ctx evt node = case evt of
    Click point btn -> result where
      child = Seq.index (node ^. L.children) 0
      childClicked = pointInRect point (child ^. L.widgetInstance . L.renderArea)
      events
        | childClicked = _boxOnClick config
        | otherwise = _boxOnClickEmpty config
      requests
        | childClicked  = _boxOnClickReq config
        | otherwise = _boxOnClickEmptyReq config
      needsUpdate = btn == LeftBtn && not (null events && null requests)
      result
        | needsUpdate = Just $ resultReqsEvts node requests events
        | otherwise = Nothing
    _ -> Nothing

  getSizeReq :: ContainerGetSizeReqHandler s e
  getSizeReq wenv node children = (newReqW, newReqH) where
    child = Seq.index children 0
    newReqW = child ^. L.widgetInstance . L.sizeReqW
    newReqH = child ^. L.widgetInstance . L.sizeReqH

  resize :: ContainerResizeHandler s e
  resize wenv viewport renderArea children node = resized where
    style = activeStyle wenv node
    contentArea = fromMaybe def (removeOuterBounds style renderArea)
    Rect cx cy cw ch = contentArea
    child = Seq.index children 0
    contentW = sizeReqMax $ child ^. L.widgetInstance . L.sizeReqW
    contentH = sizeReqMax $ child ^. L.widgetInstance . L.sizeReqH
    raChild = Rect cx cy (min cw contentW) (min ch contentH)
    ah = fromMaybe ACenter (_boxAlignH config)
    av = fromMaybe AMiddle (_boxAlignV config)
    vpContent = fromMaybe def (intersectRects viewport contentArea)
    raAligned = alignInRect ah av contentArea raChild
    vpAligned = fromMaybe def (intersectRects viewport raAligned)
    expand = fromMaybe False (_boxExpandContent config)
    resized
      | expand = (node, Seq.singleton (vpContent, contentArea))
      | otherwise = (node, Seq.singleton (vpAligned, raAligned))

alignInRect :: AlignH -> AlignV -> Rect -> Rect -> Rect
alignInRect ah av parent child = newRect where
  tempRect = alignVInRect av parent child
  newRect = alignHInRect ah parent tempRect

alignHInRect :: AlignH -> Rect -> Rect -> Rect
alignHInRect ah parent child = newRect where
  Rect px _ pw _ = parent
  Rect cx cy cw ch = child
  newX = case ah of
    ALeft -> px
    ACenter -> px + (pw - cw) / 2
    ARight -> px + pw - cw
  newRect = Rect newX cy cw ch

alignVInRect :: AlignV -> Rect -> Rect -> Rect
alignVInRect av parent child = newRect where
  Rect _ py _ ph = parent
  Rect cx cy cw ch = child
  newY = case av of
    ATop -> py
    AMiddle -> py + (ph - ch) / 2
    ABottom -> py + ph - ch
  newRect = Rect cx newY cw ch
