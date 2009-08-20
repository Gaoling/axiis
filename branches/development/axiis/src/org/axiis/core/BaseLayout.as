///////////////////////////////////////////////////////////////////////////////
//	Copyright (c) 2009 Team Axiis
//
//	Permission is hereby granted, free of charge, to any person
//	obtaining a copy of this software and associated documentation
//	files (the "Software"), to deal in the Software without
//	restriction, including without limitation the rights to use,
//	copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the
//	Software is furnished to do so, subject to the following
//	conditions:
//
//	The above copyright notice and this permission notice shall be
//	included in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//	OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////

package org.axiis.core
{
	import flash.events.*;
	import flash.geom.*;
	import flash.utils.*;
	
	import mx.core.IFactory;
	
	import org.axiis.events.ItemClickEvent;
	import org.axiis.states.State;
	
	
	// TODO This event should be moved to AbstractLayout
	/**
	 * Dispatched when invalidate is called so the DataCanvas that owns this
	 * layout can being the process of redrawing the layout.
	 */
	[Event(name="invalidateLayout", type="flash.events.Event")]
	
	/**
	 * Dispatched at the beginning of the render method. This event allowing
	 * listening objects the chance to perform any computations that will
	 * affect the layout's render process.
	 */
	[Event(name="preRender", type="flash.events.Event")]
	
	/**
	 * Dispatched before each individual child is rendered.
	 */
	[Event(name="itemPreDraw", type="flash.events.Event")]
	
	/**
	 * Dispatched when an AxiisSprite is clicked.
	 */
	[Event(name="itemClick", type="flash.events.Event")]
	
	// TODO Is "AxiisLayout" a better name for BaseLayout 
	/**
	 * BaseLayout is a data driven layout engine that uses GeometryRepeaters
	 * and PropertyModifiers to transform geometries before drawing them to
	 * the screen.
	 */
	public class BaseLayout extends AbstractLayout
	{
		/**
		 * Constructor.
		 */
		public function BaseLayout()
		{
			super();
		}

		private var allStates:Array = [];

		[Bindable(event="scaleFillChange")]
		/**
		 * Whether or not the fills in this geometry should be scaled within the
		 * bounds rectangle.
		 */
		public function get scaleFill():Boolean
		{
			return _scaleFill;
		}
		public function set scaleFill(value:Boolean):void
		{
			if(value != _scaleFill)
			{
				_scaleFill = value;
				this.invalidate();
				dispatchEvent(new Event("scaleFillChange"));
			}
		}	
		private var _scaleFill:Boolean;
		
		/**
		 * Whether or not the drawingGeometries should should have their initial
		 * bounds set to the currentReference of the parent layout.
		 */
		public var inheritParentBounds:Boolean = true;
		
		override public function set dataTipContentClass(value:IFactory) : void
		{
			super.dataTipContentClass = value;
			invalidate();
		}
		
		/**
		 * @private
		 */
		override public function set visible(value:Boolean):void
		{
			super.visible = value;
			if(sprite)
				sprite.visible = visible;
		}
		
		/** 
		 * Draws this layout to the specified AxiisSprite, tracking all changes
		 * made by data binding or the referenceRepeater. 
		 * 
		 * <p>
		 * If no sprite is provided this layout will use the last AxiisSprite
		 * it rendered to, if such an AxiisSprite exists. Otherwise this returns
		 * immediately.
		 * </p>
		 * 
		 * <p>
		 * The render cycle occurs in several stages. By watching for these
		 * events or by binding onto the currentReference, currentIndex, or the
		 * currentDatum properties, you can inject your own logic into the
		 * render cycle.  For example, if you bind a drawingGeometry's x
		 * position to currentReference.x and use a GeometryRepeater that
		 * adds 5 to the x property of the reference, the layout will render
		 * one geometry for each item in the dataProvider at every 5 pixels. 
		 * </p>
		 * 
		 * @param sprite The AxiisSprite this layout should render to.
		 */
		override public function render(newSprite:AxiisSprite = null):void 
		{
			if (!visible || !this.dataItems || itemCount==0)
			{
				if (newSprite)
					newSprite.visible = false;
				return;
			}
			
			if (newSprite)
				newSprite.visible=true;
			
			dispatchEvent(new Event("preRender"));
			
			if(newSprite)
				this.sprite = newSprite;
			_rendering = true;
			
			trimChildSprites();

			if(!sprite || !_referenceGeometryRepeater)
				return;			
			
			if (inheritParentBounds && parentLayout)
			{
				bounds = new Rectangle(parentLayout.currentReference.x + (isNaN(x) ? 0 : x),
									parentLayout.currentReference.y + (isNaN(y) ? 0 : y),
									parentLayout.currentReference.width,
									parentLayout.currentReference.height);
			}
			else
			{
				bounds = new Rectangle((isNaN(x) ? 0:x),(isNaN(y) ? 0:y),width,height);
			}
			sprite.x = isNaN(_bounds.x) ? 0 :_bounds.x;
			sprite.y = isNaN(_bounds.y) ? 0 :_bounds.y;
			
			if (_dataItems)
			{
				var topLayout:ILayout = findTopLayout();
				allStates = findAllStatesInLayoutTree(topLayout);
				
				_itemCount = _dataItems.length;
				if(_itemCount > 0)
				{
					_currentDatum = null;
					_currentValue = null;
					_currentLabel = null
					_currentIndex = -1;
					
					_referenceGeometryRepeater.repeat(itemCount, preIteration, postIteration, repeatComplete);
				}
			}
		}
		
		protected function findTopLayout():ILayout
		{
			var topLayout:ILayout = this;
			while(topLayout.parentLayout != null)
			{
				topLayout = topLayout.parentLayout;
			}
			return topLayout;
		}
		
		protected function findAllStatesInLayoutTree(layout:ILayout):Array
		{
			var toReturn:Array = [];
			for each(var state:State in layout.states)
			{
				toReturn.push(state);
			}
			for each(var childLayout:ILayout in layout.layouts)
			{
				var childLayoutStates:Array = findAllStatesInLayoutTree(childLayout);
				toReturn = toReturn.concat(childLayoutStates);
			}
			return toReturn;
		}
		
		/**
		 * The callback method called by the referenceRepeater before it applies
		 * the PropertyModifiers on each iteration. This method updates the
		 * currentIndex, currentDatum, currentValue, and currentLabel
		 * properties.  It is recommended that subclasses override this method
		 * to perform any custom data-driven computations that affect the
		 * drawingGeometries.
		 */
		protected function preIteration():void
		{
			_currentIndex = referenceRepeater.currentIteration;
			_currentDatum = dataItems[_currentIndex];			
			_currentValue=getProperty(_currentDatum,dataField);
			_currentLabel = getProperty(_currentDatum,labelField).toString();
		}

		/**
		 * The callback method called by the referenceRepeater after it applies
		 * the PropertyModifiers on each iteration. This method updates the
		 * currentReference property and creates or updates the AxiisSprite that
		 * renders the currentDatum.  It is recommended that subclasses
		 * override this method to perform any computations that affect the
		 * drawingGeometries that are based on the drawingGeometries themselves.
		 */
		protected function postIteration():void
		{
			_currentReference = referenceRepeater.geometry;
			
			// Add a new Sprite if there isn't one available on the display list.
			if(_currentIndex > sprite.drawingSprites.length - 1)
			{
				var newChildSprite:AxiisSprite = createChildSprite(this);				
				sprite.addDrawingSprite(newChildSprite);
				childSprites.push(newChildSprite);
			}
			var currentChild:AxiisSprite = AxiisSprite(sprite.drawingSprites[currentIndex]);
			currentChild.data = currentDatum;
			currentChild.label = currentLabel;
			currentChild.value = currentValue;
			currentChild.index = currentIndex;
			
			dispatchEvent(new Event("itemPreDraw"));
			
			currentChild.bounds = bounds;
			currentChild.scaleFill = scaleFill;
			currentChild.dataTipAnchorPoint = dataTipAnchorPoint == null ? null : dataTipAnchorPoint.clone();
			currentChild.dataTipContentClass = dataTipContentClass;
			
			currentChild.storeGeometries(drawingGeometries);
			for each(var state:State in allStates)
			{
				state.apply();
				currentChild.storeGeometries(drawingGeometries,state);
				state.remove();
			}
			currentChild.states = states;
			currentChild.render();
			
			renderChildLayouts(currentChild);
		}
		
		/**
		 * Calls the render method on all child layouts. 
		 */
		protected function renderChildLayouts(child:AxiisSprite):void
		{
			var i:int=0;
			for each(var layout:ILayout in layouts)
			{
				// When we have multiple peer layouts the AxiisSprite needs to
				// differentiate between child drawing sprites and child layout sprites
				layout.parentLayout = this as ILayout;
				if (child.layoutSprites.length-1 < i)
				{
					var ns:AxiisSprite = createChildSprite(this);
					child.addLayoutSprite(ns);
				}
				layout.render(child.layoutSprites[i]);
				i++;
			}
		}
		
		/**
		 * The callback method called by the referenceRepeater after it finishes
		 * its final iteration. Stop tracking changes to the drawingGeometries
		 * properties.
		 */
		protected function repeatComplete():void
		{
			sprite.visible = visible;
			_rendering = false;
		}
		
		private function createChildSprite(layout:ILayout):AxiisSprite
		{
			var newChildSprite:AxiisSprite = new AxiisSprite();
			newChildSprite.doubleClickEnabled=true;
			newChildSprite.layout = layout;
			newChildSprite.addEventListener("click",sprite_onClick);
			return newChildSprite;
		}

		private function trimChildSprites():void
		{
			if (!sprite || _itemCount < 1)
				return;
			var trim:int = sprite.drawingSprites.length-_itemCount;
			for (var i:int=0; i <trim;i++)
			{
				var s:AxiisSprite = AxiisSprite(sprite.removeChild(sprite.drawingSprites[sprite.drawingSprites.length-1]));
				s.dispose();
			}
		}
		
		private function sprite_onClick(e:Event):void {
				e.stopPropagation();
				this.dispatchEvent(new ItemClickEvent(AxiisSprite(e.currentTarget)));
		}
	}
}