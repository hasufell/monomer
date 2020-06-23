{-# LANGUAGE RecordWildCards #-}

module Monomer.Widget.Widgets.Label (label) where

import Control.Monad
import Data.Text (Text)

import Monomer.Common.Geometry
import Monomer.Common.Style
import Monomer.Common.Tree
import Monomer.Graphics.Drawing
import Monomer.Widget.BaseWidget
import Monomer.Widget.Types
import Monomer.Widget.Util

label :: Text -> WidgetInstance s e
label caption = defaultWidgetInstance "label" (makeLabel caption)

makeLabel :: Text -> Widget s e
makeLabel caption = createWidget {
    _widgetPreferredSize = preferredSize,
    _widgetRender = render
  }
  where
    preferredSize renderer wctx widgetInstance = singleNode sizeReq where
      Style{..} = _instanceStyle widgetInstance
      size = calcTextBounds renderer _textStyle (if caption == "" then " " else caption)
      sizeReq = SizeReq size FlexibleSize StrictSize

    render renderer wctx ctx WidgetInstance{..} =
      do
        drawBgRect renderer _instanceRenderArea _instanceStyle
        drawText_ renderer _instanceRenderArea (_textStyle _instanceStyle) caption
